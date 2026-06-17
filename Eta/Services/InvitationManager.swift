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
    private let analyticsService: AnalyticsService
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
        pendingReceivedRepo: PendingReceivedInvitationRepository,
        analyticsService: AnalyticsService
    ) {
        self.notificationService = notificationService
        self.modelContext = modelContext
        self.supabaseService = supabaseService
        self.phoneSetupService = phoneSetupService
        self.pendingReceivedRepo = pendingReceivedRepo
        self.analyticsService = analyticsService
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
        let hangout = fetchHangout(id: hangoutID)
        let feedback = HangoutFeedback(
            hangoutID: hangoutID,
            friendRating: friendRating,
            activityRating: activityRating
        )
        modelContext.insert(feedback)
        try modelContext.save()
        analyticsService.logFeedbackSubmitted(
            friendRating: friendRating,
            wouldRepeatActivity: activityRating > 0,
            activity: hangout?.activity ?? "",
            skipped: false
        )
        pendingFeedbackHangoutID = nil
    }

    func dismissFeedback() {
        if let hangoutID = pendingFeedbackHangoutID {
            let hangout = fetchHangout(id: hangoutID)
            analyticsService.logFeedbackSubmitted(friendRating: 0, wouldRepeatActivity: false, activity: hangout?.activity ?? "", skipped: true)
        }
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
        hangoutID: UUID,
        previousInvitationID: String? = nil,
        source: String = "suggestion"
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

        if supabaseService.isConfigured {
            // Post to Supabase regardless of whether the contact has the app registered.
            // If they do, toIdentifier matches their device for push routing.
            // If they don't, toIdentifier is empty and they accept via iMessage/web RSVP.
            let receiverDeviceID = await contactDeviceID(for: contact)
            let remote = RemoteInvitation(
                id: invitation.id,
                fromDevice: supabaseService.deviceID,
                fromIdentifier: phoneSetupService.myIdentifier ?? "",
                toIdentifier: receiverDeviceID ?? "",
                friendName: friendName,
                activity: activityName,
                startTime: scheduledTime,
                endTime: endDate,
                status: "pending",
                previousInvitationID: previousInvitationID
            )
            try await supabaseService.postInvitation(remote)
            let hangoutDescriptor = FetchDescriptor<ScheduledHangout>(predicate: #Predicate { $0.id == hangoutID })
            if let hangout = try? modelContext.fetch(hangoutDescriptor).first {
                hangout.invitationID = invitation.id
                try? modelContext.save()
            }
            await notificationService.scheduleInviteSentNotification(
                friendName: friendName,
                activityName: activityName
            )
        } else {
            // Supabase not configured — dev/demo mode only. Simulate acceptance locally.
            try await notificationService.sendInvitation(for: invitation)
        }

        await notificationService.scheduleHangoutReminders(
            hangoutID: hangoutID,
            activityName: activityName,
            friendName: friendName,
            startDate: scheduledTime,
            endDate: endDate
        )

        analyticsService.logInvitationSent(contactName: friendName, activity: activityName, source: source)

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
                    analyticsService.logHangoutConfirmed(friendName: invitation.friendName, activity: invitation.activityName)
                    Task {
                        try? await notificationService.scheduleFeedbackNotification(
                            hangoutID: hangout.id,
                            friendName: invitation.friendName,
                            activityName: invitation.activityName,
                            at: hangout.endDate
                        )
                    }
                } else {
                    analyticsService.logHangoutDeclined(friendName: invitation.friendName, activity: invitation.activityName)
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
        fromIdentifier: String,
        isEdit: Bool = false,
        delayed: Bool = false
    ) async {
        if accepted && hasOverlappingScheduledHangout(start: startTime, end: endTime) {
            try? await supabaseService.respondToInvitation(id: id, accepted: false)
            try? pendingReceivedRepo.delete(id: id)
            return
        }

        try? await supabaseService.respondToInvitation(id: id, accepted: accepted)
        try? pendingReceivedRepo.delete(id: id)

        let senderName = findContact(byIdentifier: fromIdentifier)?.name ?? fromIdentifier
        if accepted {
            analyticsService.logHangoutConfirmed(friendName: senderName, activity: activity, isEdit: isEdit, delayed: delayed)
        } else {
            analyticsService.logHangoutDeclined(friendName: senderName, activity: activity, isEdit: isEdit, delayed: delayed)
        }

        guard accepted, let sender = findContact(byIdentifier: fromIdentifier) else { return }

        let hangout = ScheduledHangout(
            contact: sender,
            activity: activity,
            selectedTime: DateInterval(start: startTime, end: endTime)
        )
        hangout.inviteeResponse = .confirmed
        hangout.invitationID = id
        modelContext.insert(hangout)
        try? modelContext.save()
        NotificationCenter.default.post(name: .scheduledHangoutsDidChange, object: nil)
    }

    // MARK: - Polling

    /// Called on every app foreground. Checks for new received invites and sent invite responses.
    func pollForUpdates() async {
        async let sent: () = pollSentInvitations()
        async let received: () = pollReceivedInvitations()
        async let cancellations: () = pollCancellations()
        _ = await (sent, received, cancellations)
        expireStaleHangouts()
    }

    func cancelEventByValues(contact: TrackedContact, invitationID: String, activity: String) async {
        guard supabaseService.isConfigured,
              let toIdentifier = await contactDeviceID(for: contact) else { return }
        let cancellation = RemoteCancellation(
            id: invitationID,
            fromIdentifier: phoneSetupService.myIdentifier ?? "",
            toIdentifier: toIdentifier,
            friendName: contact.name,
            activity: activity
        )
        try? await supabaseService.postCancellation(cancellation)
    }

    // MARK: - Web RSVP / iMessage deep link

    /// Handles `eta://invite-accepted?activity=<act>&start=<ts>&end=<ts>[&invitationID=<id>][&senderName=<name>]`.
    ///
    /// Sender path (invitationID matches a local Invitation): confirms it without creating a duplicate.
    /// Receiver path: creates a new confirmed ScheduledHangout.
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

        if let invitationID = items.first(where: { $0.name == "invitationID" })?.value,
           !invitationID.isEmpty {
            let descriptor = FetchDescriptor<Invitation>(predicate: #Predicate { $0.id == invitationID })
            if (try? modelContext.fetch(descriptor).first) != nil {
                try? handleInvitationResponse(invitationID: invitationID, accepted: true)
                return
            }
        }

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

    func hasConflict(start: Date, end: Date) -> Bool {
        hasOverlappingScheduledHangout(start: start, end: end)
    }

    private func hasOverlappingScheduledHangout(start: Date, end: Date) -> Bool {
        guard end > start else { return false }

        let descriptor = FetchDescriptor<ScheduledHangout>()
        let hangouts = (try? modelContext.fetch(descriptor)) ?? []
        return hangouts.contains {
            $0.status != .canceled &&
            $0.endDate > .now &&
            $0.startDate < end &&
            $0.endDate > start
        }
    }

    private func pollSentInvitations() async {
        guard supabaseService.isConfigured else { return }
        guard let updates = try? await supabaseService.fetchSentUpdates() else { return }
        for remote in updates {
            let descriptor = FetchDescriptor<Invitation>(predicate: #Predicate { $0.id == remote.id })
            if let inv = try? modelContext.fetch(descriptor).first {
                // App-originated invite: update existing Invitation and its ScheduledHangout.
                guard inv.status == .pending else { continue }
                let accepted = remote.status == "confirmed"
                try? handleInvitationResponse(invitationID: remote.id, accepted: accepted)
                if accepted {
                    await notificationService.scheduleInviteAcceptedNotification(
                        friendName: remote.friendName,
                        activityName: remote.activity
                    )
                } else {
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
            analyticsService.logInvitationReceived(friendName: remote.friendName, activity: remote.activity)
            print("[Poll] scheduling notification for invite=\(remote.id)")
            if let prevID = remote.previousInvitationID {
                let all = (try? modelContext.fetch(FetchDescriptor<ScheduledHangout>())) ?? []
                if let old = all.first(where: { $0.invitationID == prevID }) {
                    notificationService.cancelHangoutReminders(for: old.id)
                    modelContext.delete(old)
                    try? modelContext.save()
                }
            }
            let senderName = findContact(byIdentifier: remote.fromIdentifier)?.name ?? remote.fromIdentifier
            let isEdit = remote.previousInvitationID != nil
            try? await notificationService.scheduleReceivedInvitationNotification(remote: remote, senderName: senderName, isEdit: isEdit)
            if !pendingReceivedRepo.exists(id: remote.id) {
                try? pendingReceivedRepo.add(PendingReceivedInvitation(remote: remote, senderName: senderName, isEdit: isEdit))
            }
            receivedInviteState?.trigger(invite: remote, senderName: senderName, isEdit: isEdit)
            notified.insert(remote.id)
        }
        notifiedRemoteIDs = notified
    }

    private func pollCancellations() async {
        guard supabaseService.isConfigured else { return }
        guard let cancellations = try? await supabaseService.fetchCancellations() else { return }
        for cancellation in cancellations {
            let all = (try? modelContext.fetch(FetchDescriptor<ScheduledHangout>())) ?? []
            if let hangout = all.first(where: { $0.invitationID == cancellation.id }) {
                hangout.inviteeResponse = .declined
                try? modelContext.save()
                NotificationCenter.default.post(name: .scheduledHangoutsDidChange, object: nil)
                let friendName = findContact(byIdentifier: cancellation.fromIdentifier)?.name ?? cancellation.fromIdentifier
                analyticsService.logEventCanceledByFriend(friendName: friendName, activity: cancellation.activity)
                await notificationService.scheduleEventCanceledNotification(
                    friendName: friendName,
                    activityName: cancellation.activity
                )
            }
            await supabaseService.deleteCancellation(id: cancellation.id)
        }
    }

    private func contactDeviceID(for contact: TrackedContact) async -> String? {
        if let phone = contact.phoneNumber,
           let id = await supabaseService.lookupDeviceID(for: PhoneSetupService.normalized(phone)),
           !id.isEmpty { return id }
        if let email = contact.emailAddress?.lowercased(),
           let id = await supabaseService.lookupDeviceID(for: email),
           !id.isEmpty { return id }
        return nil
    }

    func senderName(for identifier: String) -> String {
        findContact(byIdentifier: identifier)?.name ?? identifier
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

    private func findContact(byName name: String) -> TrackedContact? {
        let all = (try? modelContext.fetch(FetchDescriptor<TrackedContact>())) ?? []
        let lower = name.lowercased()
        return all.first {
            $0.name.lowercased().contains(lower)
            || $0.givenName.lowercased() == lower
            || "\($0.givenName) \($0.familyName)".lowercased() == lower
        }
    }
}
