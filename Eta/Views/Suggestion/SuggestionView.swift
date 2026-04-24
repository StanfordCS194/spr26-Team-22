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
                } else {
                    switch viewModel.scheduleState {
                    case .accepted:
                        AcceptedView()
                    case .scheduled(let timeLabel):
                        ScheduledView(timeLabel: timeLabel, onSend: { viewModel.finishAndSend() })
                    case .idle:
                        if let suggestion = viewModel.suggestion {
                            SuggestionCard(
                                displayName: viewModel.displayName(for: suggestion),
                                timeLabel: viewModel.timeLabel(for: suggestion),
                                suggestion: suggestion,
                                onDismiss: { viewModel.dismiss() },
                                onSchedule: { viewModel.schedule() }
                            )
                        } else {
                            ContentUnavailableView(
                                "Nothing to suggest right now",
                                systemImage: "calendar.badge.clock",
                                description: Text("We'll suggest a hangout when you have free time and a friend to catch up with.")
                            )
                        }
                    }
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

// MARK: - Confirmation views

private struct AcceptedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Invitation accepted! 🎉")
                .font(.title)
                .fontWeight(.semibold)
            Text("Creating your calendar event...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct ScheduledView: View {
    let timeLabel: String
    let onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Hangout scheduled for \(timeLabel)!")
                    .font(.title)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Tap below to send the invite.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Send Invite", action: onSend)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
