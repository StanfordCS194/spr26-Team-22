import SwiftUI

/// Suggestions tab that presents the current hangout suggestion and tutorial flow.
struct SuggestionView: View {
    let viewModel: SuggestionViewModel
    let analyticsService: AnalyticsService
    let isTutorialActive: Bool
    let tutorialRequestID: Int
    let onTutorialDone: () -> Void
    let onTutorialNext: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var scheduleStartTime: Date?
    @State private var showingCustomize = false
    @State private var tutorialPhase: SuggestionsTutorialPhase = .none
    @State private var startedTutorialRequestID: Int?
    @State private var diffSuggestions: [String] = []

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
                                onCustomize: {
                                    showingCustomize = true
                                },
                                latestPhotoData: viewModel.latestPhotoData(for: suggestion),
                                onDismiss: {
                                    analyticsService.logSuggestionDismissed(contactName: viewModel.displayName(for: suggestion))
                                    completeSuggestionActionIfNeeded()
                                    viewModel.dismiss()
                                },
                                onSchedule: {
                                    let name = viewModel.displayName(for: suggestion)
                                    analyticsService.logSuggestionAccepted(
                                        contactName: name,
                                        activity: suggestion.activityDescription
                                    )
                                    scheduleStartTime = Date()
                                    completeSuggestionActionIfNeeded()
                                    viewModel.schedule()
                                },
                                analyticsService: analyticsService
                            )
                            .onAppear {
                                analyticsService.logSuggestionViewed(
                                    contactName: viewModel.displayName(for: suggestion),
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await refreshWithDifferentSuggestion()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor, in: Circle())
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Refresh suggestion")
                    .tutorialTarget(SuggestionTutorialTarget.refreshButton)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.refresh()
            startSuggestionsTutorialIfNeeded()

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
        .onChange(of: isTutorialActive) { _, isActive in
            if !isActive {
                tutorialPhase = .none
                startedTutorialRequestID = nil
            } else {
                startSuggestionsTutorialIfNeeded()
            }
        }
        .onChange(of: tutorialRequestID) { _, _ in
            startSuggestionsTutorialIfNeeded()
        }
        .overlayPreferenceValue(TutorialTargetPreferenceKey<SuggestionTutorialTarget>.self) { targets in
            GeometryReader { proxy in
                suggestionsTutorialOverlay(targets: targets, proxy: proxy)
            }
            .allowsHitTesting(tutorialPhase != .none)
        }
        .onDisappear {
            diffSuggestions = []
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
                    onDismiss: { showingCustomize = false },
                    conflictChecker: { viewModel.hasConflict(for: $0) }
                )
            }
        }
    }

    /// Renders the Suggestions tutorial slides and target pointers.
    @ViewBuilder
    private func suggestionsTutorialOverlay(
        targets: [SuggestionTutorialTarget: Anchor<CGRect>],
        proxy: GeometryProxy
    ) -> some View {
        ZStack {
            suggestionsTutorialPointers(targets: targets, proxy: proxy)
                .allowsHitTesting(false)

            if let step = tutorialPhase.walkthroughStep {
                WalkthroughOverlay(
                    steps: [step],
                    onPrimaryAction: { _ in
                        handleSuggestionsTutorialPrimaryAction()
                        return true
                    },
                    primaryButtonTitleOverride: tutorialPhase == .completeSlide ? "Next Step" : nil,
                    secondaryButtonTitle: tutorialPhase == .completeSlide ? "Done" : nil,
                    onSecondaryAction: tutorialPhase == .completeSlide ? {
                        finishSuggestionsTutorial()
                    } : nil,
                    showsBackButton: tutorialPhase.hasPreviousSlide,
                    onBackAction: {
                        goBackInSuggestionsTutorial()
                    },
                    onDismiss: {
                        finishSuggestionsTutorial()
                    }
                )
            }
        }
    }

    /// Shows all action-button pointers for the interactive Suggestions step.
    @ViewBuilder
    private func suggestionsTutorialPointers(
        targets: [SuggestionTutorialTarget: Anchor<CGRect>],
        proxy: GeometryProxy
    ) -> some View {
        if tutorialPhase == .actionPointers {
            suggestionsPointer(target: .refreshButton, in: targets, proxy: proxy, arrowType: .up, description: "Refresh!")
                .zIndex(1)
            suggestionsPointer(target: .scheduleButton, in: targets, proxy: proxy, arrowType: .down, description: "Send an invite!")
                .zIndex(2)
            suggestionsPointer(target: .detailsButton, in: targets, proxy: proxy, arrowType: .right, description: "Take a closer look.")
                .zIndex(3)
        } else {
            EmptyView()
        }
    }

    /// Anchors a Suggestions tutorial pointer to a card button when available.
    @ViewBuilder
    private func suggestionsPointer(
        target: SuggestionTutorialTarget,
        in targets: [SuggestionTutorialTarget: Anchor<CGRect>],
        proxy: GeometryProxy,
        arrowType: TutorialPointerArrowType,
        description: String
    ) -> some View {
        if let anchor = targets[target] {
            TutorialPointer(
                arrowType: arrowType,
                targetFrame: proxy[anchor],
                containerSize: proxy.size,
                description: description
            )
        }
    }

    /// Resets tracking and starts the Suggestions tutorial at its first slide.
    private func startSuggestionsTutorial() {
        tutorialPhase = .introSlide
    }

    /// Starts the Suggestions tutorial once for the active parent request.
    private func startSuggestionsTutorialIfNeeded() {
        guard isTutorialActive, tutorialRequestID > 0 else { return }
        guard startedTutorialRequestID != tutorialRequestID else { return }
        startedTutorialRequestID = tutorialRequestID
        startSuggestionsTutorial()
    }

    /// Marks the Suggestions tutorial complete and notifies the parent tab coordinator.
    private func finishSuggestionsTutorial() {
        if tutorialPhase == .completeSlide { analyticsService.logTutorialCompleted(tab: "suggestions") }
        UserDefaults.standard.set(true, forKey: "walkthrough_suggestions")
        tutorialPhase = .none
        onTutorialDone()
    }

    /// Advances the Suggestions tutorial through slides and the action-pointer phase.
    private func handleSuggestionsTutorialPrimaryAction() {
        switch tutorialPhase {
        case .introSlide:
            tutorialPhase = .inviteSlide
        case .inviteSlide:
            tutorialPhase = .refreshSlide
        case .refreshSlide:
            tutorialPhase = .actionPointers
        case .completeSlide:
            finishSuggestionsTutorial()
            onTutorialNext()
        case .none, .actionPointers:
            break
        }
    }

    /// Moves the Suggestions tutorial back to the previous slide phase.
    private func goBackInSuggestionsTutorial() {
        switch tutorialPhase {
        case .inviteSlide:
            tutorialPhase = .introSlide
        case .refreshSlide:
            tutorialPhase = .inviteSlide
        case .completeSlide:
            tutorialPhase = .refreshSlide
        case .none, .introSlide, .actionPointers:
            break
        }
    }

    /// Moves past the action-pointer phase when the user chooses a final action.
    private func completeSuggestionActionIfNeeded() {
        guard tutorialPhase == .actionPointers else { return }
        tutorialPhase = .completeSlide
    }
    private func refreshWithDifferentSuggestion() async {
        let previousSuggestion = viewModel.suggestion
        if let previousActivity = previousSuggestion?.activityDescription {
            diffSuggestions.append(previousActivity)
            diffSuggestions = Array(diffSuggestions.suffix(10))
        }

        await viewModel.refresh(
            diffContact: previousSuggestion?.contact,
            diffTime: previousSuggestion?.proposedTime,
            diffSuggestion: diffSuggestions
        )
    }

}

// MARK: - Confirmation views

/// Transitional view shown while a hangout invite is being scheduled.
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

/// Confirmation view shown after an invitation has been sent.
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

/// Step state for the Suggestions tab's interactive tutorial.
private enum SuggestionsTutorialPhase: Equatable {
    case none
    case introSlide
    case inviteSlide
    case refreshSlide
    case actionPointers
    case completeSlide

    var walkthroughStep: WalkthroughStep? {
        switch self {
        case .introSlide:
            return TabWalkthroughs.suggestions[0]
        case .inviteSlide:
            return TabWalkthroughs.suggestions[1]
        case .refreshSlide:
            return TabWalkthroughs.suggestions[2]
        case .completeSlide:
            return TabWalkthroughs.suggestions[3]
        case .none, .actionPointers:
            return nil
        }
    }

    var hasPreviousSlide: Bool {
        switch self {
        case .inviteSlide, .refreshSlide, .completeSlide:
            return true
        case .none, .introSlide, .actionPointers:
            return false
        }
    }
}
