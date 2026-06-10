import SwiftUI

/// Tabs shown in the app's root navigation.
fileprivate enum TabChoice: Hashable {
    case availability, friends, suggestions, events
}

/// The tab currently running its interactive tutorial.
private enum ActiveTabTutorial: Hashable {
    case friends
    case availability
    case suggestions
    case events
}

/// Root tab container that wires global sheets and cross-tab tutorial flow.
struct MainTabView: View {
    let homeViewModel: HomeViewModel
    let connectionsViewModel: ConnectionsViewModel
    let suggestionViewModel: SuggestionViewModel
    let upcomingEventsViewModel: UpcomingEventsViewModel
    let settingsViewModel: SettingsViewModel
    let availabilityViewModel: AvailabilityViewModel
    let analyticsService: AnalyticsService
    let invitationManager: InvitationManager
    let photoRepository: ActivityPhotoRepository
    let reminderPhotoState: ReminderPhotoState
    let nudgeService: NudgeService
    let nudgeScheduler: NudgeScheduler
    let weeklyCheckInService: WeeklyCheckInService
    let weeklyCheckInState: WeeklyCheckInState
    let nudgeReminderState: NudgeReminderState
    let receivedInviteState: ReceivedInviteState
    let chatViewModel: ChatViewModel

    @State private var selectedTab: TabChoice = .friends
    @State private var showingSettings = false
    @State private var settingsDismissCount = 0
    // The first-run walkthrough starts on Friends, then advances tab-by-tab.
    @State private var activeTutorial: ActiveTabTutorial? = MainTabView.initialTutorial
    @State private var eventsTutorialPhase: EventsTutorialPhase = .none
    @State private var tutorialRequestID = MainTabView.initialTutorialRequestID

    private static var initialTutorial: ActiveTabTutorial? {
        UserDefaults.standard.bool(forKey: "walkthrough_friends") ? nil : .friends
    }

    private static var initialTutorialRequestID: Int {
        initialTutorial == nil ? 0 : 1
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Availability", systemImage: "clock.badge.checkmark", value: .availability) {
                AvailabilityView(
                    viewModel: availabilityViewModel,
                    analyticsService: analyticsService,
                    isTutorialActive: activeTutorial == .availability,
                    tutorialRequestID: tutorialRequestID,
                    onTutorialDone: { activeTutorial = nil },
                    onTutorialNext: {
                        tutorialRequestID += 1
                        selectedTab = .suggestions
                        activeTutorial = .suggestions
                    }
                )
            }
            Tab("Friends", systemImage: "person.2.fill", value: .friends) {
                ConnectionsView(
                    viewModel: connectionsViewModel,
                    homeViewModel: homeViewModel,
                    settingsViewModel: settingsViewModel,
                    analyticsService: analyticsService,
                    weeklyCheckInState: weeklyCheckInState,
                    onShowSettings: { showingSettings = true },
                    photoRepository: photoRepository,
                    isTutorialActive: activeTutorial == .friends,
                    tutorialRequestID: tutorialRequestID,
                    settingsDismissCount: settingsDismissCount,
                    onTutorialDone: { activeTutorial = nil },
                    onTutorialNext: {
                        tutorialRequestID += 1
                        selectedTab = .availability
                        activeTutorial = .availability
                    }
                )
            }
            Tab("Events", systemImage: "cup.and.saucer", value: .events) {
                UpcomingEventsDashboard(
                    viewModel: upcomingEventsViewModel,
                    photoRepository: photoRepository,
                    analyticsService: analyticsService
                )
            }
            Tab("Suggestions", systemImage: "sparkles", value: .suggestions) {
                SuggestionView(
                    viewModel: suggestionViewModel,
                    analyticsService: analyticsService,
                    isTutorialActive: activeTutorial == .suggestions,
                    tutorialRequestID: tutorialRequestID,
                    onTutorialDone: { activeTutorial = nil },
                    onTutorialNext: {
                        tutorialRequestID += 1
                        selectedTab = .events
                        activeTutorial = .events
                        eventsTutorialPhase = .introSlide
                    }
                )
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            settingsDismissCount += 1
            connectionsViewModel.loadContacts()
            homeViewModel.recomputeAllIsRemote()
            Task { await homeViewModel.refresh() }
        }) {
            SettingsView(viewModel: settingsViewModel, onDismiss: { showingSettings = false }, analyticsService: analyticsService)
        }
        .sheet(isPresented: Binding(
            get: { invitationManager.pendingFeedbackHangoutID != nil },
            set: { if !$0 { invitationManager.dismissFeedback() } }
        )) {
            if let hangoutID = invitationManager.pendingFeedbackHangoutID {
                FeedbackPopupView(
                    hangoutID: hangoutID,
                    invitationManager: invitationManager
                )
            }
        }
        // Floating chat button — pinned above the tab bar in the bottom-trailing corner.
        .overlay(alignment: .bottomTrailing) {
            FloatingChatButton(
                viewModel: chatViewModel,
                onPresented: {
                    guard activeTutorial == .events, eventsTutorialPhase == .chatPointer else { return }
                },
                onDismissed: {
                    guard activeTutorial == .events, eventsTutorialPhase == .chatPointer else { return }
                    eventsTutorialPhase = .completeSlide
                },
                analyticsService: analyticsService
            )
            .padding(.trailing, 20)
            .padding(.bottom, 72)
        }
        .overlayPreferenceValue(TutorialTargetPreferenceKey<MainTutorialTarget>.self) { targets in
            GeometryReader { proxy in
                eventsTutorialOverlay(targets: targets, proxy: proxy)
            }
            .allowsHitTesting(eventsTutorialOverlayAllowsHitTesting)
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .availability {
                Task {
                    await availabilityViewModel.loadAvailability()
                }
            }
            if newTab == .events && activeTutorial == .events && eventsTutorialPhase == .none {
                eventsTutorialPhase = .introSlide
            }
        }
        .reminderDebug(nudgeService: nudgeService, weeklyCheckInService: weeklyCheckInService)
        .overlay(alignment: .bottomLeading) {
            if activeTutorial == nil {
                TutorialReplayButton(accessibilityLabel: "Show \(selectedTutorialName) walkthrough") {
                    startTutorialFromSelectedTab()
                }
                .padding(.leading, 20)
                .padding(.bottom, 72)
            }
        }
        .sheet(isPresented: Binding(
            get: { nudgeReminderState.isPresented },
            set: { if !$0 { nudgeReminderState.clear() } }
        )) {
            if let activityRawValue = nudgeReminderState.activityRawValue {
                let contact = connectionsViewModel.contacts.first { $0.id == nudgeReminderState.contactID }
                NudgeReminderSheet(
                    contact: contact,
                    friendName: nudgeReminderState.friendName,
                    activityRawValue: activityRawValue,
                    photoRepository: photoRepository,
                    nudgeScheduler: nudgeScheduler,
                    onScheduleNow: { suggestion in
                        analyticsService.logNudgeAction("scheduleNow", friendName: nudgeReminderState.friendName, activity: activityRawValue)
                        nudgeReminderState.clear()
                        selectedTab = .suggestions
                        suggestionViewModel.scheduleFromNudge(suggestion)
                    },
                    onSuggestions: {
                        analyticsService.logNudgeAction("viewSuggestions", friendName: nudgeReminderState.friendName, activity: activityRawValue)
                        nudgeReminderState.clear()
                        selectedTab = .suggestions
                    },
                    onDismiss: {
                        analyticsService.logNudgeAction("maybeLater", friendName: nudgeReminderState.friendName, activity: activityRawValue)
                        nudgeReminderState.clear()
                    }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { weeklyCheckInState.isPresented },
            set: { if !$0 { weeklyCheckInState.clear() } }
        )) {
            WeeklyCheckInView(
                connectionsViewModel: connectionsViewModel,
                homeViewModel: homeViewModel,
                analyticsService: analyticsService,
                onDismiss: { weeklyCheckInState.clear() },
                onViewSuggestions: {
                    weeklyCheckInState.clear()
                    selectedTab = .suggestions
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { receivedInviteState.isPresented },
            set: { if !$0 { receivedInviteState.clear(); Task { await upcomingEventsViewModel.refresh() } } }
        )) {
            if let invite = receivedInviteState.pendingInvite {
                ReceivedInviteSheet(
                    invite: invite,
                    senderName: receivedInviteState.senderName,
                    isEdit: receivedInviteState.isEdit,
                    onAccept: {
                        receivedInviteState.clear()
                        Task {
                            await invitationManager.respondToRemoteInvitation(
                                id: invite.id,
                                accepted: true,
                                activity: invite.activity,
                                startTime: invite.startTime,
                                endTime: invite.endTime,
                                fromIdentifier: invite.fromIdentifier,
                                isEdit: receivedInviteState.isEdit,
                                delayed: false
                            )
                            await upcomingEventsViewModel.refresh()
                        }
                    },
                    onDecline: {
                        receivedInviteState.clear()
                        Task {
                            await invitationManager.respondToRemoteInvitation(
                                id: invite.id,
                                accepted: false,
                                activity: invite.activity,
                                startTime: invite.startTime,
                                endTime: invite.endTime,
                                fromIdentifier: invite.fromIdentifier,
                                isEdit: receivedInviteState.isEdit,
                                delayed: false
                            )
                            await upcomingEventsViewModel.refresh()
                        }
                    },
                    onDismissedWithoutResponse: {
                        analyticsService.logInviteDelayed(
                            friendName: invite.friendName,
                            activity: invite.activity,
                            isEdit: receivedInviteState.isEdit
                        )
                    }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { reminderPhotoState.pendingActivity != nil },
            set: { if !$0 { reminderPhotoState.clear() } }
        )) {
            if let activity = reminderPhotoState.pendingActivity {
                // Priority: contact-scoped → hangout-scoped → activity-scoped.
                let photoData: Data? = reminderPhotoState.pendingContactID
                    .flatMap { photoRepository.photos(forContactID: $0).first?.imageData }
                    ?? reminderPhotoState.pendingHangoutID
                        .flatMap { photoRepository.photos(for: $0).first?.imageData }
                    ?? photoRepository.photos(for: activity).first?.imageData
                ActivityNudgeView(
                    activity: activity,
                    photoData: photoData,
                    onDismiss: { reminderPhotoState.clear() }
                )
            }
        }
    }

    /// Whether the global Events tutorial overlay currently has tappable content.
    private var eventsTutorialOverlayAllowsHitTesting: Bool {
        activeTutorial == .events
    }

    /// Label for the tab whose tutorial will start from the global help button.
    private var selectedTutorialName: String {
        switch selectedTab {
        case .availability:
            return "availability"
        case .friends:
            return "friends"
        case .suggestions:
            return "suggestions"
        case .events:
            return "events"
        }
    }

    /// Starts the tutorial sequence from the currently selected tab.
    private func startTutorialFromSelectedTab() {
        tutorialRequestID += 1
        eventsTutorialPhase = .none
        switch selectedTab {
        case .availability:
            activeTutorial = .availability
        case .friends:
            activeTutorial = .friends
        case .suggestions:
            activeTutorial = .suggestions
        case .events:
            activeTutorial = .events
            eventsTutorialPhase = .introSlide
        }
    }

    /// Renders the Events tutorial slide and chatbot pointer overlays.
    @ViewBuilder
    private func eventsTutorialOverlay(
        targets: [MainTutorialTarget: Anchor<CGRect>],
        proxy: GeometryProxy
    ) -> some View {
        ZStack {
            if activeTutorial == .events && eventsTutorialPhase == .chatPointer {
                if let anchor = targets[.chatButton] {
                    // Events owns the chat pointer from MainTabView because the chat button floats above every tab.
                    TutorialPointer(
                        arrowType: .lowerRight,
                        targetFrame: proxy[anchor],
                        containerSize: proxy.size,
                        description: "Check it out!"
                    )
                    .allowsHitTesting(false)
                }
            }

            if activeTutorial == .events, let step = eventsTutorialPhase.walkthroughStep {
                WalkthroughOverlay(
                    steps: [step],
                    onPrimaryAction: { _ in
                        handleEventsTutorialPrimaryAction()
                        return true
                    },
                    showsBackButton: eventsTutorialPhase.hasPreviousSlide,
                    onBackAction: {
                        goBackInEventsTutorial()
                    },
                    onDismiss: {
                        finishEventsTutorial()
                    }
                )
            }
        }
    }

    /// Advances the Events tutorial through its slide and pointer phases.
    private func handleEventsTutorialPrimaryAction() {
        switch eventsTutorialPhase {
        case .introSlide:
            eventsTutorialPhase = .photoSlide
        case .photoSlide:
            eventsTutorialPhase = .chatSlide
        case .chatSlide:
            eventsTutorialPhase = .chatPointer
        case .completeSlide:
            finishEventsTutorial()
        case .none, .chatPointer:
            break
        }
    }

    /// Moves the Events tutorial back to the previous slide phase.
    private func goBackInEventsTutorial() {
        switch eventsTutorialPhase {
        case .photoSlide:
            eventsTutorialPhase = .introSlide
        case .chatSlide:
            eventsTutorialPhase = .photoSlide
        case .completeSlide:
            eventsTutorialPhase = .chatSlide
        case .none, .introSlide, .chatPointer:
            break
        }
    }

    /// Marks the Events tutorial complete and clears active tutorial state.
    private func finishEventsTutorial() {
        if eventsTutorialPhase == .completeSlide { analyticsService.logTutorialCompleted(tab: "events") }
        UserDefaults.standard.set(true, forKey: "walkthrough_events")
        eventsTutorialPhase = .none
        activeTutorial = nil
    }
}

/// Step state for the Events tab's interactive tutorial.
private enum EventsTutorialPhase: Equatable {
    case none
    case introSlide
    case photoSlide
    case chatSlide
    case chatPointer
    case completeSlide

    var walkthroughStep: WalkthroughStep? {
        switch self {
        case .introSlide:
            return TabWalkthroughs.events[0]
        case .photoSlide:
            return TabWalkthroughs.events[1]
        case .chatSlide:
            return TabWalkthroughs.events[2]
        case .completeSlide:
            return TabWalkthroughs.events[3]
        case .none, .chatPointer:
            return nil
        }
    }

    var hasPreviousSlide: Bool {
        switch self {
        case .photoSlide, .chatSlide, .completeSlide:
            return true
        case .none, .introSlide, .chatPointer:
            return false
        }
    }
}
