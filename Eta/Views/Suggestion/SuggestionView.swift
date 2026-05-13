import SwiftUI

struct SuggestionView: View {
    let viewModel: SuggestionViewModel
    let analyticsService: AnalyticsService

    @Environment(\.scenePhase) private var scenePhase
    @State private var showingCustomize = false
    // Captured when the user taps "Yes, let's do it!" so we can log PlanCreated
    // after the booking completes (when viewModel.suggestion is already nil).
    @State private var pendingPlan: (contactID: UUID, name: String, activity: String)?

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
                    case .invitationSent(let friendName):
                        InvitationSentView(friendName: friendName, onDone: { viewModel.done() })
                    case .idle:
                        if let suggestion = viewModel.suggestion {
                            SuggestionCard(
                                displayName: viewModel.displayName(for: suggestion),
                                timeLabel: viewModel.timeLabel(for: suggestion),
                                suggestion: suggestion,
                                onCustomize: { showingCustomize = true },
                                latestPhotoData: viewModel.latestPhotoData(for: suggestion),
                                onDismiss: {
                                    analyticsService.logSuggestionDismissed(
                                        contactName: viewModel.displayName(for: suggestion)
                                    )
                                    viewModel.dismiss()
                                },
                                onSchedule: {
                                    pendingPlan = (
                                        contactID: suggestion.contact.id,
                                        name: viewModel.displayName(for: suggestion),
                                        activity: suggestion.activityDescription
                                    )
                                    analyticsService.logSuggestionAccepted(
                                        contactName: viewModel.displayName(for: suggestion),
                                        activity: suggestion.activityDescription
                                    )
                                    viewModel.schedule()
                                },
                                analyticsService: analyticsService
                            )
                            .onAppear {
                                analyticsService.logSuggestionGenerated(
                                    contactName: viewModel.displayName(for: suggestion),
                                    activity: suggestion.activityDescription,
                                    daysSinceLastHangout: nil
                                )
                            }
                        } else {
                            ContentUnavailableView(
                                "Nothing to suggest right now",
                                systemImage: "clock.badge.checkmark",
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
        // KPI 1 + 2: log PlanCreated when booking completes
        .onChange(of: viewModel.isInvitationSent) { _, sent in
            if sent, let plan = pendingPlan {
                analyticsService.logPlanCreated(
                    contactID: plan.contactID,
                    contactName: plan.name,
                    activity: plan.activity,
                    secondsFromLaunch: Date().timeIntervalSince(analyticsService.sessionStartTime)
                )
                pendingPlan = nil
            }
        }
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
}

// MARK: - Confirmation views

private struct AcceptedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Scheduling your hangout...")
                .font(.title)
                .fontWeight(.semibold)
            Text("Setting up your hangout and invitation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct InvitationSentView: View {
    let friendName: String
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Invitation sent to \(friendName)!")
                    .font(.title)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                Text("You'll get a notification when they respond.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
