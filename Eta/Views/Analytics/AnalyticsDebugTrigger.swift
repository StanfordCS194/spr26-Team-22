import SwiftUI

/// Protocol for defining how to trigger the analytics debug menu.
/// Swap out implementations to change the trigger mechanism.
protocol AnalyticsDebugTrigger {
    associatedtype TriggerView: View

    @ViewBuilder
    func makeTriggerView(showDebugMenu: Binding<Bool>) -> TriggerView
}

// MARK: - Triple-Tap Bottom-Right Corner

struct TripleTapBottomRightTrigger: AnalyticsDebugTrigger {
    func makeTriggerView(showDebugMenu: Binding<Bool>) -> some View {
        Color.clear
            .frame(width: 80, height: 80)
            .contentShape(Rectangle())
            .onTapGesture(count: 5) {
                showDebugMenu.wrappedValue = true
            }
            .padding(.bottom, 49)
    }
}
