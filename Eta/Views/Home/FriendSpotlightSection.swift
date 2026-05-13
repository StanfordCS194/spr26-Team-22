import SwiftUI

struct FriendSpotlightSection: View {
    let items: [FriendSpotlightItem]
    let viewModel: HomeViewModel
    let onAddFriends: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Friend Spotlight")
                .font(.title3.weight(.semibold))

            if items.isEmpty {
                spotlightEmptyState
            } else {
                ForEach(items) { item in
                    NavigationLink {
                        FriendDetailView(
                            contact: item.contact,
                            health: item.health,
                            displayName: viewModel.displayName(for: item.contact),
                            homeViewModel: viewModel,
                            onAddGoal: { /* handled inside FriendDetailView */ }
                        )
                    } label: {
                        FriendSpotlightCard(
                            item: item,
                            displayName: viewModel.displayName(for: item.contact)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var spotlightEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Once you've added some friends, they'll show up here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Add friends", action: onAddFriends)
                .font(.subheadline.weight(.medium))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}
