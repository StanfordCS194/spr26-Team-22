import UserNotifications

final class LocalNotificationService: NotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()
    // Simulated delay before "friend accepts" — short enough to demo clearly.
    private let simulatedDelay: TimeInterval = 5.0

    func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { throw NotificationError.permissionDenied }
    }

    func sendInvitation(for invitation: Invitation) async throws {
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

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum NotificationError: Error {
    case permissionDenied
}
