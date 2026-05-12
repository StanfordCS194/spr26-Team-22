import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let invitationManager: InvitationManager
    private let reminderPhotoState: ReminderPhotoState

    init(invitationManager: InvitationManager, reminderPhotoState: ReminderPhotoState) {
        self.invitationManager = invitationManager
        self.reminderPhotoState = reminderPhotoState
    }

    // Called when a notification arrives while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        handleResponse(from: notification.request.content.userInfo)
        return [.banner, .sound]
    }

    // Called when the user taps the notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        handleResponse(from: response.notification.request.content.userInfo)
    }

    private func handleResponse(from userInfo: [AnyHashable: Any]) {
        if let type = userInfo["notificationType"] as? String, type == "photoCapture" {
            let rawValue = userInfo["activityRawValue"] as? String ?? ""
            let activity = Activity(rawValue: rawValue) ?? .walk
            let hangoutID = (userInfo["hangoutID"] as? String).flatMap { UUID(uuidString: $0) }
            Task { @MainActor in
                reminderPhotoState.trigger(activity: activity, hangoutID: hangoutID)
            }
            return
        }

        guard let invitationID = userInfo["invitationID"] as? String else { return }
        // Simulated for Demo Day 1: always treat as accepted.
        try? invitationManager.handleInvitationResponse(invitationID: invitationID, accepted: true)
    }
}
