import SwiftUI

fileprivate enum TabChoice: Hashable {
    case friends, events, suggestions
}

struct MainTabView: View {
    let homeViewModel: HomeViewModel
    let connectionsViewModel: ConnectionsViewModel
    let suggestionViewModel: SuggestionViewModel
    let upcomingEventsViewModel: UpcomingEventsViewModel
    let analyticsService: AnalyticsService
    let photoRepository: ActivityPhotoRepository
    let reminderPhotoState: ReminderPhotoState
    let nudgeService: NudgeService
    let nudgeScheduler: NudgeScheduler
    let weeklyCheckInService: WeeklyCheckInService
    let weeklyCheckInState: WeeklyCheckInState
    let nudgeReminderState: NudgeReminderState

    @State private var selectedTab: TabChoice = .events

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Friends", systemImage: "person.2.fill", value: .friends) {
                ConnectionsView(
                    viewModel: connectionsViewModel,
                    homeViewModel: homeViewModel,
                    analyticsService: analyticsService
                )
            }
            Tab("Events", systemImage: "cup.and.saucer", value: .events) {
                UpcomingEventsDashboard(
                    viewModel: upcomingEventsViewModel,
                    photoRepository: photoRepository
                )
            }
            Tab("Suggestions", systemImage: "sparkles", value: .suggestions) {
                SuggestionView(
                    viewModel: suggestionViewModel,
                    analyticsService: analyticsService
                )
            }
        }
        .analyticsDebug(service: analyticsService)
        .reminderDebug(nudgeService: nudgeService, weeklyCheckInService: weeklyCheckInService)
        .sheet(isPresented: Binding(
            get: { nudgeReminderState.isPresented },
            set: { if !$0 { nudgeReminderState.clear() } }
        )) {
            if let activityRawValue = nudgeReminderState.activityRawValue {
                let contact = connectionsViewModel.contacts.first { $0.id == nudgeReminderState.contactID }
                NudgeReminderSheet(
                    contact: contact,
                    friendName: nudgeReminderState.friendName,
                    activityRawValue: activityRawValue,
                    photoRepository: photoRepository,
                    nudgeScheduler: nudgeScheduler,
                    onScheduleNow: { suggestion in
                        nudgeReminderState.clear()
                        selectedTab = .activites
                        suggestionViewModel.scheduleFromNudge(suggestion)
                    },
                    onSuggestions: {
                        nudgeReminderState.clear()
                        selectedTab = .activites
                    },
                    onDismiss: { nudgeReminderState.clear() }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { weeklyCheckInState.isPresented },
            set: { if !$0 { weeklyCheckInState.clear() } }
        )) {
            WeeklyCheckInView(
                connectionsViewModel: connectionsViewModel,
                onDismiss: { weeklyCheckInState.clear() }
            )
        }
        .sheet(isPresented: Binding(
            get: { reminderPhotoState.pendingActivity != nil },
            set: { if !$0 { reminderPhotoState.clear() } }
        )) {
            if let activity = reminderPhotoState.pendingActivity {
                // Priority: contact-scoped → hangout-scoped → activity-scoped.
                let photoData: Data? = reminderPhotoState.pendingContactID
                    .flatMap { photoRepository.photos(forContactID: $0).first?.imageData }
                    ?? reminderPhotoState.pendingHangoutID
                        .flatMap { photoRepository.photos(for: $0).first?.imageData }
                    ?? photoRepository.photos(for: activity).first?.imageData
                ActivityNudgeView(
                    activity: activity,
                    photoData: photoData,
                    onDismiss: { reminderPhotoState.clear() }
                )
            }
        }
    }
}
