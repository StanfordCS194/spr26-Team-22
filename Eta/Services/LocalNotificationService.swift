import UserNotifications

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

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum NotificationError: Error {
    case permissionDenied
}
