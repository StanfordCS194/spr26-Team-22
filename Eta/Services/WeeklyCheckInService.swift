import Foundation
import UserNotifications

/// Schedules a repeating weekly notification encouraging the user to check in
/// with their friends. Fires every Sunday at 6pm.
///
/// Scheduled once — repeats automatically via UNCalendarNotificationTrigger.
/// Re-calling scheduleIfNeeded() is idempotent: skips if already pending.
final class WeeklyCheckInService {
    private static let notificationID = "me.Eta.weeklyCheckIn"

    /// Fires the weekly check-in notification in 3 seconds for debug/demo purposes.
    func scheduleDebug() async {
        let content = UNMutableNotificationContent()
        content.title = "How are your friendships doing?"
        content.body = "Take a moment to check in with someone this week."
        content.sound = .default
        content.userInfo = ["notificationType": "weeklyCheckIn"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "me.Eta.weeklyCheckIn.debug.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleIfNeeded() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        guard !pending.contains(where: { $0.identifier == Self.notificationID }) else { return }

        let content = UNMutableNotificationContent()
        content.title = "How are your friendships doing?"
        content.body = "Take a moment to check in with someone this week."
        content.sound = .default
        content.userInfo = ["notificationType": "weeklyCheckIn"]

        var components = DateComponents()
        components.weekday = 1  // Sunday
        components.hour = 18    // 6pm
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.notificationID,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
