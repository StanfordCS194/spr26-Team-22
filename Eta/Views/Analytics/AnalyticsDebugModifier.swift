//
//  AnalyticsDebugModifier.swift
//  Eta
//
//  Created on 4/23/26.
//

import SwiftUI

/// View modifier that adds analytics debug functionality.
/// The trigger mechanism is configurable - just swap out the trigger type.
///
/// Usage:
///   .analyticsDebug(service: analyticsService, trigger: TripleTapBottomRightTrigger())
struct AnalyticsDebugModifier<Trigger: AnalyticsDebugTrigger>: ViewModifier {
    let analyticsService: AnalyticsService
    let trigger: Trigger

    @State private var showingDebugMenu = false

    func body(content: Content) -> some View {
        ZStack(alignment: .bottomLeading) {
            content

            #if DEBUG
            trigger.makeTriggerView(showDebugMenu: $showingDebugMenu)
            #endif
        }
        .sheet(isPresented: $showingDebugMenu) {
            AnalyticsDebugOverlay(analyticsService: analyticsService)
                .presentationDetents([.medium, .large])
        }
    }
}

extension View {
    func analyticsDebug<Trigger: AnalyticsDebugTrigger>(
        service: AnalyticsService,
        trigger: Trigger = TripleTapBottomRightTrigger()
    ) -> some View {
        modifier(AnalyticsDebugModifier(analyticsService: service, trigger: trigger))
    }
}
