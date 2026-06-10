import UserNotifications

@MainActor
final class LocalNotificationService: NotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()
    private let preferencesService: PreferencesService
    // Simulated delay before "friend accepts"
    private let simulatedDelay: TimeInterval = 10.0

    init(preferencesService: PreferencesService) {
        self.preferencesService = preferencesService
    }

    func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { throw NotificationError.permissionDenied }
    }

    func sendInvitation(for invitation: Invitation) async throws {
        // Skip if notifications are disabled
        guard preferencesService.preferences.enableNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Eta"
        content.body = "\(invitation.friendName) accepted your invite for \(invitation.activityName) at \(formattedTime(invitation.scheduledTime))!"
        content.sound = .default
        content.userInfo = ["invitationID": invitation.id]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: simulatedDelay, repeats: false)
        let request = UNNotificationRequest(
            identifier: "invitation-response-\(invitation.id)",
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    func cancelNotification(for invitationID: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["invitation-response-\(invitationID)"])
    }

    func scheduleFeedbackNotification(hangoutID: UUID, friendName: String, activityName: String, at date: Date) async throws {
        guard preferencesService.preferences.enableNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "How was it?"
        content.body = "Rate your \(activityName) with \(friendName)!"
        content.sound = .default
        content.userInfo = ["feedbackHangoutID": hangoutID.uuidString]
        
        let interval = max(date.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "feedback-\(hangoutID.uuidString)",
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    func scheduleHangoutReminders(hangoutID: UUID, activityName: String, friendName: String, startDate: Date, endDate: Date) async {
        guard preferencesService.preferences.enableNotifications else { return }

        let headsUpTime = startDate.addingTimeInterval(-30 * 60)
        if headsUpTime > .now {
            let content = UNMutableNotificationContent()
            content.title = "Heads up!"
            content.body = "Your \(activityName.lowercased()) with \(friendName) starts in 30 minutes."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: headsUpTime),
                repeats: false
            )
            try? await center.add(UNNotificationRequest(
                identifier: "hangout-headsup-\(hangoutID)",
                content: content,
                trigger: trigger
            ))
        }

        if endDate > .now {
            let content = UNMutableNotificationContent()
            content.title = activityName
            content.body = "You just spent time with \(friendName). Tap to relive it."
            content.sound = .default
            content.userInfo = [
                "notificationType": "photoCapture",
                "activityRawValue": activityName,
                "hangoutID": hangoutID.uuidString
            ]
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: endDate),
                repeats: false
            )
            try? await center.add(UNNotificationRequest(
                identifier: "hangout-photo-\(hangoutID)",
                content: content,
                trigger: trigger
            ))
        }
    }

    func cancelHangoutReminders(for hangoutID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [
            "hangout-headsup-\(hangoutID)",
            "hangout-photo-\(hangoutID)"
        ])
    }

    func scheduleReceivedInvitationNotification(remote: RemoteInvitation) async throws {
        guard preferencesService.preferences.enableNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(remote.friendName) invited you!"
        content.body = "\(remote.activity) — \(formattedDateTime(remote.startTime))"
        content.sound = .default
        content.categoryIdentifier = "INVITE_RESPONSE"
        content.userInfo = [
            "notificationType": "receivedInvite",
            "remoteInvitationID": remote.id,
            "activity": remote.activity,
            "startTime": remote.startTime.timeIntervalSince1970,
            "endTime": remote.endTime.timeIntervalSince1970,
            "fromIdentifier": remote.fromIdentifier,
            "friendName": remote.friendName
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "received-invite-\(remote.id)",
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    func scheduleInviteSentNotification(friendName: String, activityName: String) async {
        guard preferencesService.preferences.enableNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "Invite sent!"
        content.body = "We let \(friendName) know about \(activityName)."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "invite-sent-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func scheduleInviteDeclinedNotification(friendName: String, activityName: String) async {
        guard preferencesService.preferences.enableNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "Invite declined"
        content.body = "\(friendName) can't make it for \(activityName)."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "invite-declined-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func scheduleFriendNudgeNotification(fromName: String) async {
        guard preferencesService.preferences.enableNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(fromName) wants to hang out!"
        content.body = "They're thinking of you — why not reach out?"
        content.sound = .default
        content.userInfo = ["notificationType": "friendNudge", "fromName": fromName]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "friend-nudge-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum NotificationError: Error {
    case permissionDenied
}
