import SwiftUI

struct MainTabView: View {
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
                // Replaced by ConnectionsView in PR 2
                ContentUnavailableView(
                    "No Friends Yet",
                    systemImage: "person.2",
                    description: Text("Your tracked friends will appear here.")
                )
            }
        }
    }
}

#Preview {
    MainTabView()
}
