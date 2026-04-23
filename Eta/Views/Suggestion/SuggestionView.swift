import SwiftUI

struct SuggestionView: View {
    let viewModel: SuggestionViewModel

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let suggestion = viewModel.suggestion {
                    SuggestionCard(
                        displayName: viewModel.displayName(for: suggestion),
                        timeLabel: viewModel.timeLabel(for: suggestion),
                        suggestion: suggestion,
                        onDismiss: { viewModel.dismiss() }
                    )
                } else {
                    ContentUnavailableView(
                        "Nothing to suggest right now",
                        systemImage: "calendar.badge.clock",
                        description: Text("We'll suggest a hangout when you have free time and a friend to catch up with.")
                    )
                }
            }
            .navigationTitle("For You")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refresh()
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
