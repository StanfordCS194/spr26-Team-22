//
//  AnalyticsDebugTrigger.swift
//  Eta
//
//  Created on 4/23/26.
//

import SwiftUI

/// Protocol for defining how to trigger the analytics debug menu.
/// Swap out implementations to change the trigger mechanism.
protocol AnalyticsDebugTrigger {
    associatedtype TriggerView: View
    
    @ViewBuilder
    func makeTriggerView(showDebugMenu: Binding<Bool>) -> TriggerView
}

// MARK: - Triple-Tap Bottom-Right Corner

/// Triggers debug menu via triple-tap in bottom-right corner.
struct TripleTapBottomRightTrigger: AnalyticsDebugTrigger {
    func makeTriggerView(showDebugMenu: Binding<Bool>) -> some View {
        Color.clear
            .frame(width: 80, height: 80)
            .contentShape(Rectangle())
            .onTapGesture(count: 3) {
                showDebugMenu.wrappedValue = true
            }
    }
}

// MARK: - Long Press Logo (Alternative)

/// Triggers debug menu via 3-second long press on a specific view.
struct LongPressLogoTrigger: AnalyticsDebugTrigger {
    func makeTriggerView(showDebugMenu: Binding<Bool>) -> some View {
        Text("Eta") // Or use Image("logo")
            .onLongPressGesture(minimumDuration: 3.0) {
                showDebugMenu.wrappedValue = true
            }
    }
}

// MARK: - Shake Gesture (Alternative)

/// Triggers debug menu via device shake.
struct ShakeGestureTrigger: AnalyticsDebugTrigger {
    func makeTriggerView(showDebugMenu: Binding<Bool>) -> some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                showDebugMenu.wrappedValue = true
            }
    }
}

// MARK: - Shake Notification

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

#if DEBUG
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}
#endif
