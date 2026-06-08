import Foundation
import SwiftData

@MainActor
@Observable
final class InvitationManager {
    private let notificationService: any NotificationServiceProtocol
    private let modelContext: ModelContext
    private let supabaseService: SupabaseService
    private let phoneSetupService: PhoneSetupService
    private let pendingReceivedRepo: PendingReceivedInvitationRepository
    var pendingFeedbackHangoutID: UUID?
    var receivedInviteState: ReceivedInviteState?

    /// Invitation IDs for which we have already scheduled a received-invite notification.
    private var notifiedRemoteIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "notifiedRemoteInvitationIDs") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "notifiedRemoteInvitationIDs") }
    }

    init(
        notificationService: any NotificationServiceProtocol,
        modelContext: ModelContext,
        supabaseService: SupabaseService,
        phoneSetupService: PhoneSetupService,
        pendingReceivedRepo: PendingReceivedInvitationRepository
    ) {
        self.notificationService = notificationService
        self.modelContext = modelContext
        self.supabaseService = supabaseService
        self.phoneSetupService = phoneSetupService
        self.pendingReceivedRepo = pendingReceivedRepo
    }

    /// Cancels the heads-up and photo-capture notifications scheduled for a hangout.
    func cancelHangoutReminders(for hangoutID: UUID) {
        notificationService.cancelHangoutReminders(for: hangoutID)
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

        if supabaseService.isConfigured,
           let receiverDeviceID = await supabaseService.lookupDeviceID(for: contactIdentifier(for: contact)),
           !receiverDeviceID.isEmpty {
            let remote = RemoteInvitation(
                id: invitation.id,
                fromDevice: supabaseService.deviceID,
                fromIdentifier: phoneSetupService.myIdentifier ?? "",
                toIdentifier: receiverDeviceID,
                friendName: friendName,
                activity: activityName,
                startTime: scheduledTime,
                endTime: endDate,
                status: "pending"
            )
            try await supabaseService.postInvitation(remote)
            await notificationService.scheduleInviteSentNotification(
                friendName: friendName,
                activityName: activityName
            )
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
        try? pendingReceivedRepo.delete(id: id)

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
        expireStaleHangouts()
    }

    // MARK: - Private

    private func expireStaleHangouts() {
        let now = Date()
        let descriptor = FetchDescriptor<ScheduledHangout>(
            predicate: #Predicate { $0.endDate < now }
        )
        let stale = (try? modelContext.fetch(descriptor))?.filter {
            $0.inviteeResponse == .pending
        } ?? []
        if !stale.isEmpty {
            for hangout in stale { hangout.inviteeResponse = .declined }
            try? modelContext.save()
            NotificationCenter.default.post(name: .scheduledHangoutsDidChange, object: nil)
        }
        try? pendingReceivedRepo.deleteExpired()
    }

    private func pollSentInvitations() async {
        guard supabaseService.isConfigured else { return }
        guard let updates = try? await supabaseService.fetchSentUpdates() else { return }
        for remote in updates {
            let descriptor = FetchDescriptor<Invitation>(predicate: #Predicate { $0.id == remote.id })
            guard let inv = try? modelContext.fetch(descriptor).first,
                  inv.status == .pending else { continue }
            let accepted = remote.status == "confirmed"
            try? handleInvitationResponse(invitationID: remote.id, accepted: accepted)
            if !accepted {
                await notificationService.scheduleInviteDeclinedNotification(
                    friendName: remote.friendName,
                    activityName: remote.activity
                )
            }
            await supabaseService.deleteInvitation(id: remote.id)
        }
        await supabaseService.deleteExpiredSentInvitations()
    }

    private func pollReceivedInvitations() async {
        guard supabaseService.isConfigured else {
            print("[Poll] skipped — not configured")
            return
        }
        guard let pending = try? await supabaseService.fetchPendingReceived() else {
            print("[Poll] fetch failed")
            return
        }
        print("[Poll] found \(pending.count) pending invite(s)")

        var notified = notifiedRemoteIDs
        for remote in pending {
            print("[Poll] invite id=\(remote.id) alreadyNotified=\(notified.contains(remote.id))")
            if remote.endTime < Date() {
                await supabaseService.deleteInvitation(id: remote.id)
                continue
            }
            guard !notified.contains(remote.id) else { continue }
            print("[Poll] scheduling notification for invite=\(remote.id)")
            let senderName = findContact(byIdentifier: remote.fromIdentifier)?.name ?? remote.fromIdentifier
            try? await notificationService.scheduleReceivedInvitationNotification(remote: remote, senderName: senderName)
            if !pendingReceivedRepo.exists(id: remote.id) {
                try? pendingReceivedRepo.add(PendingReceivedInvitation(remote: remote, senderName: senderName))
            }
            receivedInviteState?.trigger(invite: remote, senderName: senderName)
            notified.insert(remote.id)
        }
        notifiedRemoteIDs = notified
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
