import Foundation

/// Shared observable state that signals the UI to present the photo capture sheet.
/// Set by NotificationDelegate when a photo-capture notification is tapped,
/// or directly by the debug trigger.
@Observable
final class ReminderPhotoState {
    var pendingActivity: Activity? = nil
    var pendingHangoutID: UUID? = nil

    func trigger(activity: Activity, hangoutID: UUID? = nil) {
        pendingActivity = activity
        pendingHangoutID = hangoutID
    }

    func clear() {
        pendingActivity = nil
        pendingHangoutID = nil
    }
}
