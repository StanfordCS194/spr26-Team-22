import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let invitationManager: InvitationManager

    init(invitationManager: InvitationManager) {
        self.invitationManager = invitationManager
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
        if let feedbackIDString = userInfo["feedbackHangoutID"] as? String,
           let hangoutID = UUID(uuidString: feedbackIDString) {
            Task { @MainActor in
                invitationManager.pendingFeedbackHangoutID = hangoutID
            }
            return
        }

        guard let invitationID = userInfo["invitationID"] as? String else { return }
        // Simulated for Demo Day 1: always treat as accepted.
        try? invitationManager.handleInvitationResponse(invitationID: invitationID, accepted: true)
    }
}
