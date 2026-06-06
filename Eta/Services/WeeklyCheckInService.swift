import Foundation
import UserNotifications

/// Schedules the weekly check-in notification using the user's configured day and time.
/// Independent of the global `enableNotifications` preference — has its own toggle.
final class WeeklyCheckInService {
    private static let notificationID = "me.Eta.weeklyCheckIn"
    private let preferencesService: PreferencesService

    init(preferencesService: PreferencesService) {
        self.preferencesService = preferencesService
    }

    /// Schedules the notification if not already pending and check-ins are enabled.
    func scheduleIfNeeded() async {
        guard preferencesService.preferences.weeklyCheckInEnabled else {
            await cancel()
            return
        }
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        guard !pending.contains(where: { $0.identifier == Self.notificationID }) else { return }
        await schedule()
    }

    /// Cancels any pending notification and reschedules with current preferences.
    /// Call this after the user changes the day or time in Settings.
    func reschedule() async {
        await cancel()
        await scheduleIfNeeded()
    }

    /// Fires in 1 second for debug/demo purposes.
    func scheduleDebug() async {
        let content = makeContent()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "me.Eta.weeklyCheckIn.debug.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Private

    private func cancel() async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func schedule() async {
        let prefs = preferencesService.preferences
        let cal = Calendar.current
        var components = DateComponents()
        components.weekday = prefs.weeklyCheckInDay
        components.hour = cal.component(.hour, from: prefs.weeklyCheckInTime)
        components.minute = cal.component(.minute, from: prefs.weeklyCheckInTime)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.notificationID,
            content: makeContent(),
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func makeContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "How are your friendships doing?"
        content.body = "Take a moment to check in with someone this week."
        content.sound = .default
        content.userInfo = ["notificationType": "weeklyCheckIn"]
        return content
    }
}
