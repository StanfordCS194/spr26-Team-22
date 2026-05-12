import SwiftUI

fileprivate enum TabChoice: Hashable {
    case friends, events, activites
}

struct MainTabView: View {
    let connectionsViewModel: ConnectionsViewModel
    let suggestionViewModel: SuggestionViewModel
    let upcomingEventsViewModel: UpcomingEventsViewModel
    let analyticsService: AnalyticsService
    let photoRepository: ActivityPhotoRepository
    let reminderPhotoState: ReminderPhotoState

    @State private var selectedTab: TabChoice = .events

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Friends", systemImage: "person.2", value: .friends) {
                ConnectionsView(
                    viewModel: connectionsViewModel,
                    analyticsService: analyticsService
                )
            }
            Tab("Events", systemImage: "cup.and.saucer", value: .events) {
                UpcomingEventsDashboard(
                    viewModel: upcomingEventsViewModel,
                    photoRepository: photoRepository
                )
            }
            Tab("Suggestions", systemImage: "sparkles", value: .activites) {
                SuggestionView(
                    viewModel: suggestionViewModel,
                    analyticsService: analyticsService
                )
            }
        }
        .analyticsDebug(service: analyticsService)
        .reminderDebug(photoRepository: photoRepository, photoState: reminderPhotoState)
        .sheet(isPresented: Binding(
            get: { reminderPhotoState.pendingActivity != nil },
            set: { if !$0 { reminderPhotoState.clear() } }
        )) {
            if let activity = reminderPhotoState.pendingActivity {
                ReminderPhotoSheet(
                    activity: activity,
                    hangoutID: reminderPhotoState.pendingHangoutID,
                    existingPhotos: photoRepository.photos(for: activity).map { $0.imageData },
                    onSave: { data in
                        let photo = ActivityPhoto(
                            activity: activity,
                            hangoutID: reminderPhotoState.pendingHangoutID,
                            imageData: data
                        )
                        try? photoRepository.add(photo)
                        reminderPhotoState.clear()
                    },
                    onDismiss: { reminderPhotoState.clear() }
                )
            }
        }
    }
}
