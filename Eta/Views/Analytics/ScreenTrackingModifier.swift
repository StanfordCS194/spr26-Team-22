//
//  ScreenTrackingModifier.swift
//  Eta
//
//  Created on 4/23/26.
//

import SwiftUI

/// View modifier that automatically tracks when a screen is viewed and exited,
/// including time spent on the screen.
struct ScreenTrackingModifier: ViewModifier {
    let screenName: String
    let analyticsService: AnalyticsService?

    func body(content: Content) -> some View {
        content
            .onAppear {
                analyticsService?.logScreenViewed(screen: screenName)
            }
            .onDisappear {
                analyticsService?.logScreenExited(screen: screenName)
            }
    }
}

extension View {
    func trackScreen(_ name: String, analytics: AnalyticsService?) -> some View {
        modifier(ScreenTrackingModifier(screenName: name, analyticsService: analytics))
    }
}
