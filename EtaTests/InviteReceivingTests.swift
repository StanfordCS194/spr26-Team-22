import Testing
import SwiftData
import Foundation
@testable import Eta

// MARK: - Mock notification service

@MainActor
private final class MockNotificationService: NotificationServiceProtocol {
    func requestAuthorization() async throws {}
    func sendInvitation(for invitation: Invitation) async throws {}
    func cancelNotification(for invitationID: String) {}
    func scheduleFeedbackNotification(hangoutID: UUID, friendName: String, activityName: String, at date: Date) async throws {}
    func scheduleHangoutReminders(hangoutID: UUID, activityName: String, friendName: String, startDate: Date, endDate: Date) async {}
    func cancelHangoutReminders(for hangoutID: UUID) {}
    func scheduleReceivedInvitationNotification(remote: RemoteInvitation) async throws {}
    func scheduleInviteSentNotification(friendName: String, activityName: String) async {}
    func scheduleInviteDeclinedNotification(friendName: String, activityName: String) async {}
}

// MARK: - Tests

/// Tests for the iMessage invite receiving flow (handleInviteURL).
///
/// SupabaseService.isConfigured is false in the test bundle (no Info.plist keys),
/// so all Supabase code paths are no-ops and no network calls are made.
@MainActor
struct InviteReceivingTests {

    let manager: InvitationManager
    let ctx: ModelContext
    // Held strongly so SwiftData doesn't tear down mid-test.
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: TrackedContact.self, ScheduledHangout.self,
                Invitation.self, PendingReceivedInvitation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        ctx = container.mainContext
        manager = InvitationManager(
            notificationService: MockNotificationService(),
            modelContext: ctx,
            supabaseService: SupabaseService(),
            phoneSetupService: PhoneSetupService(),
            pendingReceivedRepo: PendingReceivedInvitationRepository(modelContext: ctx)
        )
    }

    // MARK: - Receiver path

    @Test("Receiver: creates a confirmed ScheduledHangout with 'via iMessage' fallback name")
    func receiverPath_createsHangout() throws {
        let url = URL(string: "eta://invite-accepted?activity=Walk&start=1755000000&end=1755003600")!
        manager.handleInviteURL(url)

        let hangouts = try ctx.fetch(FetchDescriptor<ScheduledHangout>())
        #expect(hangouts.count == 1)
        #expect(hangouts[0].activity == "Walk")
        #expect(hangouts[0].inviteeResponse == .confirmed)
        #expect(hangouts[0].contact == nil)
        #expect(hangouts[0].contactName == "via iMessage")
    }

    @Test("Receiver: senderName param links to an existing TrackedContact")
    func receiverPath_senderName_linksContact() throws {
        let contact = TrackedContact(cnContactIdentifier: "c1", name: "Alice Smith",
            givenName: "Alice", familyName: "Smith")
        ctx.insert(contact)

        let url = URL(string: "eta://invite-accepted?activity=Coffee&start=1755000000&end=1755003600&senderName=Alice%20Smith")!
        manager.handleInviteURL(url)

        let hangouts = try ctx.fetch(FetchDescriptor<ScheduledHangout>())
        #expect(hangouts.count == 1)
        #expect(hangouts[0].contact?.name == "Alice Smith")
    }

    @Test("Receiver: missing activity param → no hangout created")
    func receiverPath_missingActivity_noHangout() throws {
        let url = URL(string: "eta://invite-accepted?start=1755000000&end=1755003600")!
        manager.handleInviteURL(url)

        let hangouts = try ctx.fetch(FetchDescriptor<ScheduledHangout>())
        #expect(hangouts.isEmpty)
    }

    @Test("Receiver: missing start timestamp → no hangout created")
    func receiverPath_missingStart_noHangout() throws {
        let url = URL(string: "eta://invite-accepted?activity=Walk")!
        manager.handleInviteURL(url)

        let hangouts = try ctx.fetch(FetchDescriptor<ScheduledHangout>())
        #expect(hangouts.isEmpty)
    }

    @Test("Receiver: missing end timestamp → endDate defaults to start + 1 hour")
    func receiverPath_missingEnd_defaultsDuration() throws {
        let url = URL(string: "eta://invite-accepted?activity=Walk&start=1755000000")!
        manager.handleInviteURL(url)

        let hangouts = try ctx.fetch(FetchDescriptor<ScheduledHangout>())
        #expect(hangouts.count == 1)
        let expectedEnd = Date(timeIntervalSince1970: 1755000000 + 3600)
        #expect(hangouts[0].endDate == expectedEnd)
    }

    // MARK: - Sender path (invitationID present)

    @Test("Sender: invitationID matches local Invitation → confirms it without creating a duplicate")
    func senderPath_confirmsExisting_noDuplicate() throws {
        let contact = TrackedContact(cnContactIdentifier: "c1", name: "Bob Jones",
            givenName: "Bob", familyName: "Jones")
        ctx.insert(contact)

        let hangoutID = UUID()
        let interval = DateInterval(
            start: Date(timeIntervalSince1970: 1755000000),
            end:   Date(timeIntervalSince1970: 1755003600)
        )
        let hangout = ScheduledHangout(id: hangoutID, contact: contact, activity: "Walk", selectedTime: interval)
        ctx.insert(hangout)

        let invID = UUID().uuidString
        let inv = Invitation(id: invID, activityName: "Walk", friendName: "Bob Jones",
            scheduledTime: Date(timeIntervalSince1970: 1755000000), hangoutID: hangoutID)
        ctx.insert(inv)
        try ctx.save()

        let url = URL(string: "eta://invite-accepted?activity=Walk&start=1755000000&end=1755003600&invitationID=\(invID)")!
        manager.handleInviteURL(url)

        let hangouts = try ctx.fetch(FetchDescriptor<ScheduledHangout>())
        #expect(hangouts.count == 1, "Should not create a duplicate ScheduledHangout")
        #expect(hangouts[0].inviteeResponse == .confirmed)

        let invitations = try ctx.fetch(FetchDescriptor<Invitation>())
        #expect(invitations[0].status == .confirmed)
    }

    @Test("Sender: invitationID present but unrecognised → falls through to receiver path")
    func senderPath_unknownID_takesReceiverPath() throws {
        let url = URL(string: "eta://invite-accepted?activity=Walk&start=1755000000&end=1755003600&invitationID=no-such-id")!
        manager.handleInviteURL(url)

        let hangouts = try ctx.fetch(FetchDescriptor<ScheduledHangout>())
        #expect(hangouts.count == 1)
        #expect(hangouts[0].inviteeResponse == .confirmed)
    }
}
