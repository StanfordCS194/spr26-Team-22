import SwiftUI

struct ReminderDebugModifier: ViewModifier {
    let nudgeService: NudgeService
    let weeklyCheckInService: WeeklyCheckInService

    func body(content: Content) -> some View {
        ZStack(alignment: .bottomLeading) {
            content

            #if DEBUG
            Color.clear
                .frame(width: 80, height: 80)
                .contentShape(Rectangle())
                .onTapGesture(count: 4) {
                    Task { await weeklyCheckInService.scheduleDebug() }
                }
                .onTapGesture(count: 3) {
                    Task { await nudgeService.scheduleNudge(force: true) }
                }
                .padding(.bottom, 49)
            #endif
        }
    }
}

extension View {
    func reminderDebug(nudgeService: NudgeService, weeklyCheckInService: WeeklyCheckInService) -> some View {
        modifier(ReminderDebugModifier(nudgeService: nudgeService, weeklyCheckInService: weeklyCheckInService))
    }
}
