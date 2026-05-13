import SwiftUI

fileprivate enum TabChoice: Hashable {
    case availability, friends, activites, events

}

struct MainTabView: View {
    let connectionsViewModel: ConnectionsViewModel
    let suggestionViewModel: SuggestionViewModel
    let upcomingEventsViewModel: UpcomingEventsViewModel
    let availabilityViewModel: AvailabilityViewModel
    let analyticsService: AnalyticsService
    
    @State private var selectedTab: TabChoice = .events

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Availability", systemImage: "clock.badge.checkmark", value: .availability) {
                            AvailabilityView(
                                viewModel: availabilityViewModel
                            )
            }
            Tab("Friends", systemImage: "person.2", value: .friends) {
                ConnectionsView(
                    viewModel: connectionsViewModel,
                    analyticsService: analyticsService
                )
            }
            
            
            Tab("Suggestions", systemImage: "sparkles", value: .activites) {
                SuggestionView(
                    viewModel: suggestionViewModel,
                    analyticsService: analyticsService
                )
            }
            
            Tab("Events", systemImage: "cup.and.saucer", value: .events) {
                UpcomingEventsDashboard(viewModel: upcomingEventsViewModel)
            }
        }
        .analyticsDebug(service: analyticsService)
        .onChange(of: selectedTab) { _, newTab in
            guard newTab == .availability else { return }
            Task {
                await availabilityViewModel.loadAvailability()
            }
        }
    }
}
