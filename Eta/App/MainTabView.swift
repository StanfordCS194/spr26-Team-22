import SwiftUI

struct MainTabView: View {
    let connectionsViewModel: ConnectionsViewModel

    var body: some View {
        TabView {
            Tab("For You", systemImage: "sparkles") {
                // Replaced by SuggestionView in PR 4
                ContentUnavailableView(
                    "Suggestions Coming Soon",
                    systemImage: "sparkles",
                    description: Text("Add friends first, then we'll find the right hangout for you.")
                )
            }
            Tab("Friends", systemImage: "person.2") {
                ConnectionsView(viewModel: connectionsViewModel)
            }
        }
    }
}
