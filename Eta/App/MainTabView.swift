import SwiftUI

struct MainTabView: View {
    let connectionsViewModel: ConnectionsViewModel
    let suggestionViewModel: SuggestionViewModel

    var body: some View {
        TabView {
            Tab("For You", systemImage: "sparkles") {
                SuggestionView(viewModel: suggestionViewModel)
            }
            Tab("Friends", systemImage: "person.2") {
                ConnectionsView(viewModel: connectionsViewModel)
            }
        }
    }
}
