import Foundation

/// Signals the UI to present the WeeklyCheckInView.
/// Written by NotificationDelegate on notification tap; read by MainTabView.
@Observable final class WeeklyCheckInState {
    var isPresented = false

    func trigger() { isPresented = true }
    func clear() { isPresented = false }
}
