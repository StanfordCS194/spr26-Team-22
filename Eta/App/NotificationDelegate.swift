import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let invitationManager: InvitationManager
    private let reminderPhotoState: ReminderPhotoState
    private let weeklyCheckInState: WeeklyCheckInState
    private let nudgeReminderState: NudgeReminderState

    init(
        invitationManager: InvitationManager,
        reminderPhotoState: ReminderPhotoState,
        weeklyCheckInState: WeeklyCheckInState,
        nudgeReminderState: NudgeReminderState
    ) {
        self.invitationManager = invitationManager
        self.reminderPhotoState = reminderPhotoState
        self.weeklyCheckInState = weeklyCheckInState
        self.nudgeReminderState = nudgeReminderState
    }

    // Called when a notification arrives while the app is in the foreground.
    // photoCapture and weeklyCheckIn notifications skip auto-handling — they only
    // open their screens when the user explicitly taps the notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let type = notification.request.content.userInfo["notificationType"] as? String
        let tapOnlyTypes: Set<String> = ["photoCapture", "weeklyCheckIn", "nudge"]
        if !tapOnlyTypes.contains(type ?? "") {
            handleResponse(from: notification.request.content.userInfo)
        }
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
        let type = userInfo["notificationType"] as? String

        if type == "photoCapture" {
            let rawValue = userInfo["activityRawValue"] as? String ?? ""
            let activity = Activity(rawValue: rawValue) ?? .walk
            let hangoutID = (userInfo["hangoutID"] as? String).flatMap { UUID(uuidString: $0) }
            let contactID = (userInfo["contactID"] as? String).flatMap { UUID(uuidString: $0) }
            Task { @MainActor in
                reminderPhotoState.trigger(activity: activity, hangoutID: hangoutID, contactID: contactID)
            }
            return
        }

        if type == "weeklyCheckIn" {
            Task { @MainActor in weeklyCheckInState.trigger() }
            return
        }

        if type == "nudge" {
            let activityRawValue = userInfo["activityRawValue"] as? String ?? ""
            let contactID = (userInfo["contactID"] as? String).flatMap { UUID(uuidString: $0) }
            let friendName = userInfo["friendName"] as? String
            Task { @MainActor in
                nudgeReminderState.trigger(contactID: contactID, friendName: friendName, activityRawValue: activityRawValue)
            }
            return
        }

        guard let invitationID = userInfo["invitationID"] as? String else { return }
        // Simulated for Demo Day 1: always treat as accepted.
        try? invitationManager.handleInvitationResponse(invitationID: invitationID, accepted: true)
    }
}
