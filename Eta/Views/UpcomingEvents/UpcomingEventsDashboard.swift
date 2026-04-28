import SwiftUI

struct UpcomingEventsDashboard: View {
    let viewModel: UpcomingEventsViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.upcomingItems.isEmpty {
                    ContentUnavailableView(
                        "No upcoming events",
                        systemImage: "calendar",
                        description: Text("When you schedule a hangout, it'll appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.upcomingItems) { item in
                                UpcomingEventCardView(item: item)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        EventHistoryView(items: viewModel.allItems)
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                    }
                }
            }
        }
        .task {
            await viewModel.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refresh() }
            }
        }
    }
}
