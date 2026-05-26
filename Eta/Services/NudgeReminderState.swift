import Foundation

/// Signals the UI to present NudgeReminderSheet.
/// Written by NotificationDelegate on nudge notification tap; read by MainTabView.
@Observable final class NudgeReminderState {
    private(set) var contactID: UUID?
    private(set) var friendName: String?
    private(set) var activityRawValue: String?

    var isPresented: Bool { activityRawValue != nil }

    func trigger(contactID: UUID?, friendName: String?, activityRawValue: String) {
        self.contactID = contactID
        self.friendName = friendName
        self.activityRawValue = activityRawValue
    }

    func clear() {
        contactID = nil
        friendName = nil
        activityRawValue = nil
    }
}
