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
    // receivedInvite, photoCapture, weeklyCheckIn, and nudge only open their
    // screens when the user explicitly taps — skip auto-handling for all of them.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let type = notification.request.content.userInfo["notificationType"] as? String
        let tapOnlyTypes: Set<String> = ["photoCapture", "weeklyCheckIn", "nudge", "receivedInvite"]
        if !tapOnlyTypes.contains(type ?? "") {
            handleResponse(from: notification.request.content.userInfo)
        }
        return [.banner, .sound]
    }

    // Called when the user taps the notification (or an action button on it).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        // Received invite — user tapped Accept or Decline action button.
        if let remoteID = userInfo["remoteInvitationID"] as? String {
            let accepted = response.actionIdentifier == "ACCEPT_INVITE"
            let activity = userInfo["activity"] as? String ?? ""
            let startTime = Date(timeIntervalSince1970: userInfo["startTime"] as? TimeInterval ?? 0)
            let endTime   = Date(timeIntervalSince1970: userInfo["endTime"]   as? TimeInterval ?? 0)
            let fromIdentifier = userInfo["fromIdentifier"] as? String ?? ""
            Task { @MainActor in
                await invitationManager.respondToRemoteInvitation(
                    id: remoteID,
                    accepted: accepted,
                    activity: activity,
                    startTime: startTime,
                    endTime: endTime,
                    fromIdentifier: fromIdentifier
                )
            }
            return
        }

        handleResponse(from: userInfo)
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
        // Simulated for contacts outside the demo set: always treat as accepted.
        try? invitationManager.handleInvitationResponse(invitationID: invitationID, accepted: true)
    }
}
