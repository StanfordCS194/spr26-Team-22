import SwiftUI

struct SuggestionView: View {
    let viewModel: SuggestionViewModel
    let socialWarmth: Double
    let contactDaysSinceLastHangout: Int?
    let analyticsService: AnalyticsService

    @Environment(\.scenePhase) private var scenePhase
    @State private var scheduleStartTime: Date?
    @State private var showingCustomize = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Always-present ink background
                EtaColor.ink0.ignoresSafeArea()

                // Living orb field — Suggestions screen only
                OrbBackgroundView(socialWarmth: socialWarmth)

                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(EtaColor.warm)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        switch viewModel.scheduleState {
                        case .accepted:
                            AcceptedView()
                        case .invitationSent(let friendName):
                            InvitationSentView(
                                friendName: friendName,
                                socialWarmth: socialWarmth,
                                onDone: { viewModel.done() }
                            )
                        case .idle:
                            if let suggestion = viewModel.suggestion {
                                SuggestionCard(
                                    displayName: viewModel.displayName(for: suggestion),
                                    timeLabel: viewModel.timeLabel(for: suggestion),
                                    suggestion: suggestion,
                                    onCustomize: { showingCustomize = true },
                                    latestPhotoData: viewModel.latestPhotoData(for: suggestion),
                                    onDismiss: {
                                        analyticsService.logSuggestionDismissed(contactName: viewModel.displayName(for: suggestion))
                                        viewModel.dismiss()
                                    },
                                    onSchedule: {
                                        let name = viewModel.displayName(for: suggestion)
                                        let hour = Calendar.current.component(.hour, from: suggestion.proposedTime.start)
                                        let timeOfDay: String
                                        switch hour {
                                        case 5..<12: timeOfDay = "morning"
                                        case 12..<18: timeOfDay = "afternoon"
                                        default:      timeOfDay = "evening"
                                        }
                                        analyticsService.logInvitationInitiated(
                                            contactName: name,
                                            activity: suggestion.activityDescription,
                                            timeOfDay: timeOfDay,
                                            isFreeSlotSuggested: true
                                        )
                                        scheduleStartTime = Date()
                                        viewModel.schedule()
                                    },
                                    analyticsService: analyticsService,
                                    daysSinceLastHangout: contactDaysSinceLastHangout,
                                    socialWarmth: socialWarmth
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .onAppear {
                                    analyticsService.logSuggestionViewed(
                                        contactName: viewModel.displayName(for: suggestion),
                                        daysSinceLastHangout: nil
                                    )
                                }
                            } else {
                                emptyState
                            }
                        }
                    }
                }
            }
            .navigationTitle("For You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.refresh()

            if let suggestion = viewModel.suggestion {
                analyticsService.logSuggestionsGenerated(
                    count: 1,
                    contactNames: [viewModel.displayName(for: suggestion)]
                )
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refresh() }
            }
        }
        .trackScreen("SuggestionView", analytics: analyticsService)
        .sheet(isPresented: $showingCustomize) {
            if let suggestion = viewModel.suggestion {
                SuggestionDetailSheet(
                    displayName: viewModel.displayName(for: suggestion),
                    reason: suggestion.reason,
                    initialActivity: suggestion.activityDescription,
                    initialTime: suggestion.proposedTime.start,
                    onConfirm: { activity, time in
                        viewModel.customize(activity: activity, time: time)
                        showingCustomize = false
                    },
                    onDismiss: { showingCustomize = false }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("You're all caught up.")
                .font(.title2.weight(.semibold))
                .foregroundStyle(EtaColor.text1)
            Text("We'll suggest a hangout when you have free time and a friend to catch up with.")
                .font(.subheadline)
                .foregroundStyle(EtaColor.text2)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Confirmation views

private struct AcceptedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Scheduling your hangout...")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(EtaColor.text1)
            Text("Setting up your hangout and invitation.")
                .font(.subheadline)
                .foregroundStyle(EtaColor.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct InvitationSentView: View {
    let friendName: String
    let socialWarmth: Double
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Invitation sent to \(friendName)!")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(EtaColor.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Text("You'll get a notification when they respond.")
                    .font(.subheadline)
                    .foregroundStyle(EtaColor.text2)
            }

            Spacer()

            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(EtaColor.ink0)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(EtaColor.orbGradient(s: socialWarmth), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
