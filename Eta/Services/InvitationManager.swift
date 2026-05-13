import Foundation
import SwiftData

@MainActor
@Observable
final class InvitationManager {
    private let notificationService: any NotificationServiceProtocol
    private let modelContext: ModelContext
    private let supabaseService: SupabaseService
    private let phoneSetupService: PhoneSetupService
    var pendingFeedbackHangoutID: UUID?

    /// Normalized identifiers for all 5 demo team members, read from DEMO_CONTACTS in xcconfig.
    private var demoIdentifiers: Set<String> {
        let raw = Bundle.main.object(forInfoDictionaryKey: "DEMO_CONTACTS") as? String ?? ""
        return Set(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    /// Invitation IDs for which we have already scheduled a received-invite notification.
    private var notifiedRemoteIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "notifiedRemoteInvitationIDs") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "notifiedRemoteInvitationIDs") }
    }

    init(
        notificationService: any NotificationServiceProtocol,
        modelContext: ModelContext,
        supabaseService: SupabaseService,
        phoneSetupService: PhoneSetupService
    ) {
        self.notificationService = notificationService
        self.modelContext = modelContext
        self.supabaseService = supabaseService
        self.phoneSetupService = phoneSetupService
    }

    func fetchHangout(id: UUID) -> ScheduledHangout? {
        let descriptor = FetchDescriptor<ScheduledHangout>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func submitFeedback(hangoutID: UUID, friendRating: Int, activityRating: Int) throws {
        let feedback = HangoutFeedback(
            hangoutID: hangoutID,
            friendRating: friendRating,
            activityRating: activityRating
        )
        modelContext.insert(feedback)
        try modelContext.save()
        pendingFeedbackHangoutID = nil
    }

    func dismissFeedback() {
        pendingFeedbackHangoutID = nil
    }

    /// Creates a pending invitation and either POSTs to Supabase (demo contact) or
    /// schedules a simulated local acceptance notification (all other contacts).
    func acceptSuggestion(
        contact: TrackedContact,
        activityName: String,
        friendName: String,
        scheduledTime: Date,
        endDate: Date,
        hangoutID: UUID
    ) async throws -> Invitation {
        try? await notificationService.requestAuthorization()

        let invitation = Invitation(
            activityName: activityName,
            friendName: friendName,
            scheduledTime: scheduledTime,
            hangoutID: hangoutID
        )
        modelContext.insert(invitation)
        try modelContext.save()

        print("[Invite] isDemoContact=\(isDemoContact(contact)) isConfigured=\(supabaseService.isConfigured) contact=\(contactIdentifier(for: contact))")
        if isDemoContact(contact) && supabaseService.isConfigured {
            let toIdentifier = contactIdentifier(for: contact)
            let remote = RemoteInvitation(
                id: invitation.id,
                fromDevice: supabaseService.deviceID,
                fromIdentifier: phoneSetupService.myIdentifier ?? "",
                toIdentifier: toIdentifier,
                friendName: friendName,
                activity: activityName,
                startTime: scheduledTime,
                endTime: endDate,
                status: "pending"
            )
            try await supabaseService.postInvitation(remote)
        } else {
            try await notificationService.sendInvitation(for: invitation)
        }

        await notificationService.scheduleHangoutReminders(
            hangoutID: hangoutID,
            activityName: activityName,
            friendName: friendName,
            startDate: scheduledTime,
            endDate: endDate
        )

        return invitation
    }

    /// Marks the invitation as confirmed or declined and updates the linked ScheduledHangout.
    func handleInvitationResponse(invitationID: String, accepted: Bool) throws {
        let descriptor = FetchDescriptor<Invitation>(
            predicate: #Predicate { $0.id == invitationID }
        )
        guard let invitation = try modelContext.fetch(descriptor).first else { return }
        invitation.status = accepted ? .confirmed : .declined

        if let hangoutID = invitation.hangoutID {
            let hangoutDescriptor = FetchDescriptor<ScheduledHangout>(
                predicate: #Predicate { $0.id == hangoutID }
            )
            if let hangout = try modelContext.fetch(hangoutDescriptor).first {
                hangout.inviteeResponse = accepted ? .confirmed : .declined

                if accepted {
                    Task {
                        try? await notificationService.scheduleFeedbackNotification(
                            hangoutID: hangout.id,
                            friendName: invitation.friendName,
                            activityName: invitation.activityName,
                            at: hangout.endDate
                        )
                    }
                }
            }
        }

        try modelContext.save()
        NotificationCenter.default.post(name: .scheduledHangoutsDidChange, object: nil)
    }

    // MARK: - Remote invite response (receiver side)

    /// Called by NotificationDelegate when the user taps Accept or Decline on a received invite.
    /// On accept, creates a confirmed ScheduledHangout on the receiver's device.
    func respondToRemoteInvitation(
        id: String,
        accepted: Bool,
        activity: String,
        startTime: Date,
        endTime: Date,
        fromIdentifier: String
    ) async {
        try? await supabaseService.respondToInvitation(id: id, accepted: accepted)

        guard accepted, let sender = findContact(byIdentifier: fromIdentifier) else { return }

        let hangout = ScheduledHangout(
            contact: sender,
            activity: activity,
            selectedTime: DateInterval(start: startTime, end: endTime)
        )
        hangout.inviteeResponse = .confirmed
        modelContext.insert(hangout)
        try? modelContext.save()
        NotificationCenter.default.post(name: .scheduledHangoutsDidChange, object: nil)
    }

    // MARK: - Polling

    /// Called on every app foreground. Checks for new received invites and sent invite responses.
    func pollForUpdates() async {
        async let sent: () = pollSentInvitations()
        async let received: () = pollReceivedInvitations()
        _ = await (sent, received)
    }

    // MARK: - Private

    private func pollSentInvitations() async {
        guard supabaseService.isConfigured else { return }
        guard let updates = try? await supabaseService.fetchSentUpdates() else { return }
        for remote in updates {
            try? handleInvitationResponse(invitationID: remote.id, accepted: remote.status == "confirmed")
        }
    }

    private func pollReceivedInvitations() async {
        guard supabaseService.isConfigured,
              let myIdentifier = phoneSetupService.myIdentifier else {
            print("[Poll] skipped — configured=\(supabaseService.isConfigured) myIdentifier=\(phoneSetupService.myIdentifier ?? "nil")")
            return
        }
        print("[Poll] fetching for identifier=\(myIdentifier)")
        guard let pending = try? await supabaseService.fetchPendingReceived(forIdentifier: myIdentifier) else {
            print("[Poll] fetch failed")
            return
        }
        print("[Poll] found \(pending.count) pending invite(s)")

        var notified = notifiedRemoteIDs
        for remote in pending where !notified.contains(remote.id) {
            try? await notificationService.scheduleReceivedInvitationNotification(remote: remote)
            notified.insert(remote.id)
        }
        notifiedRemoteIDs = notified
    }

    private func isDemoContact(_ contact: TrackedContact) -> Bool {
        let demos = demoIdentifiers
        if let phone = contact.phoneNumber,
           demos.contains(PhoneSetupService.normalized(phone)) { return true }
        if let email = contact.emailAddress?.lowercased(),
           demos.contains(email) { return true }
        return false
    }

    private func contactIdentifier(for contact: TrackedContact) -> String {
        if let phone = contact.phoneNumber { return PhoneSetupService.normalized(phone) }
        return contact.emailAddress?.lowercased() ?? ""
    }

    private func findContact(byIdentifier identifier: String) -> TrackedContact? {
        let all = (try? modelContext.fetch(FetchDescriptor<TrackedContact>())) ?? []
        return all.first { contact in
            if let phone = contact.phoneNumber,
               PhoneSetupService.normalized(phone) == identifier { return true }
            if let email = contact.emailAddress?.lowercased(),
               email == identifier { return true }
            return false
        }
    }
}
