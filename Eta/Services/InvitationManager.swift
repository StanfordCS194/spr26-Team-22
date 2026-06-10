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

    /// Creates a pending invitation.
    ///
    /// - If the contact has a registered Supabase device, routes via push notification
    ///   and returns `wasSentToAppUser = true`.
    /// - If Supabase is configured but the contact has no device, posts a record anyway
    ///   (using their phone/email as `to_identifier`) so the web RSVP link can update it.
    ///   Returns `wasSentToAppUser = false` — the caller should open an iMessage fallback.
    /// - If Supabase is not configured, simulates acceptance locally.
    func acceptSuggestion(
        contact: TrackedContact,
        activityName: String,
        friendName: String,
        scheduledTime: Date,
        endDate: Date,
        hangoutID: UUID
    ) async throws -> (invitation: Invitation, wasSentToAppUser: Bool) {
        try? await notificationService.requestAuthorization()

        let invitation = Invitation(
            activityName: activityName,
            friendName: friendName,
            scheduledTime: scheduledTime,
            hangoutID: hangoutID
        )
        modelContext.insert(invitation)
        try modelContext.save()

        var wasSentToAppUser = false

        if supabaseService.isConfigured {
            let receiverDeviceID = await supabaseService.lookupDeviceID(for: contactIdentifier(for: contact))
            let hasDevice = (receiverDeviceID ?? "").isEmpty == false
            let remote = RemoteInvitation(
                id: invitation.id,
                fromDevice: supabaseService.deviceID,
                fromIdentifier: phoneSetupService.myIdentifier ?? "",
                toIdentifier: hasDevice ? receiverDeviceID! : contactIdentifier(for: contact),
                friendName: friendName,
                activity: activityName,
                startTime: scheduledTime,
                endTime: endDate,
                status: "pending"
            )
            try await supabaseService.postInvitation(remote)
            if hasDevice {
                wasSentToAppUser = true
                await notificationService.scheduleInviteSentNotification(
                    friendName: friendName,
                    activityName: activityName
                )
            }
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

        return (invitation, wasSentToAppUser)
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
            if let inv = try? modelContext.fetch(descriptor).first {
                // App-originated invite: update the existing Invitation and its ScheduledHangout.
                guard inv.status == .pending else { continue }
                let accepted = remote.status == "confirmed"
                try? handleInvitationResponse(invitationID: remote.id, accepted: accepted)
                if !accepted {
                    await notificationService.scheduleInviteDeclinedNotification(
                        friendName: remote.friendName,
                        activityName: remote.activity
                    )
                }
                await supabaseService.deleteInvitation(id: remote.id)
            } else if remote.status == "confirmed" {
                // Extension-originated invite: no local Invitation exists.
                // Create a confirmed ScheduledHangout so the sender sees the accepted event.
                let name = remote.friendName.isEmpty ? nil : remote.friendName
                let contact = name.flatMap { findContact(byName: $0) }
                let interval = DateInterval(start: remote.startTime, end: remote.endTime)
                let hangout: ScheduledHangout
                if let contact {
                    hangout = ScheduledHangout(contact: contact, activity: remote.activity, selectedTime: interval)
                } else {
                    hangout = ScheduledHangout(contactName: name ?? "via iMessage", activity: remote.activity, selectedTime: interval)
                }
                hangout.inviteeResponse = .confirmed
                modelContext.insert(hangout)
                try? modelContext.save()
                NotificationCenter.default.post(name: .scheduledHangoutsDidChange, object: nil)
                await supabaseService.deleteInvitation(id: remote.id)
            }
            // Extension-originated declined invites have no local record to update; let them expire.
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
            try? await notificationService.scheduleReceivedInvitationNotification(remote: remote)
            if !pendingReceivedRepo.exists(id: remote.id) {
                try? pendingReceivedRepo.add(PendingReceivedInvitation(remote: remote))
            }
            receivedInviteState?.trigger(invite: remote)
            notified.insert(remote.id)
        }
        notifiedRemoteIDs = notified
    }

    // MARK: - Web RSVP / iMessage deeplink

    /// Handles `eta://invite-accepted?activity=<act>&start=<ts>&end=<ts>[&invitationID=<id>][&senderName=<name>]`.
    ///
    /// - Sender path (invitationID matches a local Invitation): confirms the existing Invitation and
    ///   its linked ScheduledHangout rather than creating a duplicate record.
    /// - Receiver path (no matching Invitation): creates a new confirmed ScheduledHangout.
    func handleInviteURL(_ url: URL) {
        guard url.scheme == "eta", url.host == "invite-accepted",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return }

        let activity = items.first { $0.name == "activity" }?.value ?? ""
        guard !activity.isEmpty else { return }

        let startTs = Double(items.first { $0.name == "start" }?.value ?? "") ?? 0
        let endTs   = Double(items.first { $0.name == "end"   }?.value ?? "") ?? 0
        guard startTs > 0 else { return }

        let startDate = Date(timeIntervalSince1970: startTs)
        let endDate   = endTs > 0 ? Date(timeIntervalSince1970: endTs) : startDate.addingTimeInterval(3600)
        let interval  = DateInterval(start: startDate, end: endDate)

        // Sender path: if an invitationID is present and a local Invitation exists, just confirm it.
        if let invitationID = items.first(where: { $0.name == "invitationID" })?.value,
           !invitationID.isEmpty {
            let descriptor = FetchDescriptor<Invitation>(predicate: #Predicate { $0.id == invitationID })
            if (try? modelContext.fetch(descriptor).first) != nil {
                try? handleInvitationResponse(invitationID: invitationID, accepted: true)
                return
            }
        }

        // Receiver path: create a new confirmed hangout.
        let senderName = items.first { $0.name == "senderName" }?.value
        let contact    = senderName.flatMap { findContact(byName: $0) }

        let hangout: ScheduledHangout
        if let contact {
            hangout = ScheduledHangout(contact: contact, activity: activity, selectedTime: interval)
        } else {
            hangout = ScheduledHangout(
                contactName: senderName ?? "via iMessage",
                activity: activity,
                selectedTime: interval
            )
        }
        hangout.inviteeResponse = .confirmed
        modelContext.insert(hangout)
        try? modelContext.save()
        NotificationCenter.default.post(name: .scheduledHangoutsDidChange, object: nil)
    }

    private func contactIdentifier(for contact: TrackedContact) -> String {
        if let phone = contact.phoneNumber { return PhoneSetupService.normalized(phone) }
        return contact.emailAddress?.lowercased() ?? ""
    }

    private func findContact(byName name: String) -> TrackedContact? {
        let all = (try? modelContext.fetch(FetchDescriptor<TrackedContact>())) ?? []
        let lower = name.lowercased()
        return all.first {
            $0.name.lowercased().contains(lower)
            || $0.givenName.lowercased() == lower
            || "\($0.givenName) \($0.familyName)".lowercased() == lower
        }
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
