import SwiftUI

struct MainTabView: View {
    let connectionsViewModel: ConnectionsViewModel
    let suggestionViewModel: SuggestionViewModel
    let analyticsService: AnalyticsService

    var body: some View {
        TabView {
            Tab("For You", systemImage: "sparkles") {
                SuggestionView(
                    viewModel: suggestionViewModel,
                    analyticsService: analyticsService
                )
            }
            Tab("Friends", systemImage: "person.2") {
                ConnectionsView(
                    viewModel: connectionsViewModel,
                    analyticsService: analyticsService
                )
            }
        }
        .analyticsDebug(service: analyticsService)
    }
}
