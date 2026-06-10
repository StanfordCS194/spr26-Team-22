import SwiftUI

fileprivate enum TabChoice: Hashable {
    case availability, friends, suggestions, events
}

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

    @State private var selectedTab: TabChoice = .events
    @State private var showingSettings = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Availability", systemImage: "clock.badge.checkmark", value: .availability) {
                AvailabilityView(
                    viewModel: availabilityViewModel,
                    analyticsService: analyticsService
                )
                .walkthrough(key: "availability", steps: TabWalkthroughs.availability)
            }
            Tab("Friends", systemImage: "person.2.fill", value: .friends) {
                ConnectionsView(
                    viewModel: connectionsViewModel,
                    homeViewModel: homeViewModel,
                    settingsViewModel: settingsViewModel,
                    analyticsService: analyticsService,
                    weeklyCheckInState: weeklyCheckInState,
                    onShowSettings: { showingSettings = true },
                    photoRepository: photoRepository
                )
                .walkthrough(key: "friends", steps: TabWalkthroughs.friends)
            }
            Tab("Events", systemImage: "cup.and.saucer", value: .events) {
                UpcomingEventsDashboard(
                    viewModel: upcomingEventsViewModel,
                    photoRepository: photoRepository,
                    analyticsService: analyticsService
                )
                .walkthrough(key: "events", steps: TabWalkthroughs.events)
            }
            Tab("Suggestions", systemImage: "sparkles", value: .suggestions) {
                SuggestionView(
                    viewModel: suggestionViewModel,
                    analyticsService: analyticsService
                )
                .walkthrough(key: "suggestions", steps: TabWalkthroughs.suggestions)
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
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
            FloatingChatButton(viewModel: chatViewModel, analyticsService: analyticsService)
                .padding(.trailing, 20)
                .padding(.bottom, 72) // clears the tab bar (≈49pt) + breathing room
        }
        .onChange(of: selectedTab) { _, newTab in
            guard newTab == .availability else { return }
            Task {
                await availabilityViewModel.loadAvailability()
            }
        }
        .reminderDebug(nudgeService: nudgeService, weeklyCheckInService: weeklyCheckInService)
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
}
