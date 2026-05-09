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

    @State private var selectedTab: TabChoice = .friends

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
                UpcomingEventsDashboard(viewModel: upcomingEventsViewModel)
            }
            Tab("Suggestions", systemImage: "sparkles", value: .suggestions) {
                SuggestionView(
                    viewModel: suggestionViewModel,
                    analyticsService: analyticsService
                )
            }
        }
        .analyticsDebug(service: analyticsService)
    }
}
