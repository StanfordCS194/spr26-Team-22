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

    @State private var selectedTab: TabChoice = .suggestions
    @State private var showingSettings = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: .availability) {
                AvailabilityView(viewModel: availabilityViewModel)
            } label: {
                tabLabel("Availability", systemImage: "clock.badge.checkmark", isActive: selectedTab == .availability)
            }
            Tab(value: .friends) {
                ConnectionsView(
                    viewModel: connectionsViewModel,
                    homeViewModel: homeViewModel,
                    analyticsService: analyticsService,
                    onShowSettings: { showingSettings = true },
                    onNudge: { contact in
                        Task { await invitationManager.sendFriendNudge(to: contact) }
                    }
                )
            } label: {
                tabLabel("Friends", systemImage: "person.2.fill", isActive: selectedTab == .friends)
            }
            Tab(value: .events) {
                UpcomingEventsDashboard(
                    viewModel: upcomingEventsViewModel,
                    photoRepository: photoRepository
                )
            } label: {
                tabLabel("Events", systemImage: "cup.and.saucer", isActive: selectedTab == .events)
            }
            Tab(value: .suggestions) {
                SuggestionView(
                    viewModel: suggestionViewModel,
                    socialWarmth: connectionsViewModel.socialWarmth,
                    contactDaysSinceLastHangout: suggestionViewModel.suggestion.flatMap {
                        connectionsViewModel.healthScores[$0.contact.id]?.daysSinceLastHangout
                    },
                    analyticsService: analyticsService
                )
            } label: {
                tabLabel("Suggestions", systemImage: "sparkles", isActive: selectedTab == .suggestions)
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            connectionsViewModel.loadContacts()
            homeViewModel.recomputeAllIsRemote()
            Task { await homeViewModel.refresh() }
        }) {
            SettingsView(viewModel: settingsViewModel, onDismiss: { showingSettings = false })
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
            FloatingChatButton(viewModel: chatViewModel)
                .padding(.trailing, 20)
                .padding(.bottom, 72) // clears the tab bar (≈49pt) + breathing room
        }
        .analyticsDebug(service: analyticsService)
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
                        nudgeService.recordEngagement()
                        nudgeReminderState.clear()
                        selectedTab = .suggestions
                        suggestionViewModel.scheduleFromNudge(suggestion)
                    },
                    onSuggestions: {
                        nudgeService.recordEngagement()
                        nudgeReminderState.clear()
                        selectedTab = .suggestions
                    },
                    onDismiss: {
                        nudgeService.recordDismissal()
                        nudgeReminderState.clear()
                    },
                    onReduceFrequency: {
                        nudgeService.reduceFrequency()
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
                onDismiss: { weeklyCheckInState.clear() }
            )
        }
        .sheet(isPresented: Binding(
            get: { receivedInviteState.isPresented },
            set: { if !$0 { receivedInviteState.clear(); Task { await upcomingEventsViewModel.refresh() } } }
        )) {
            if let invite = receivedInviteState.pendingInvite {
                ReceivedInviteSheet(
                    invite: invite,
                    onAccept: {
                        receivedInviteState.clear()
                        Task {
                            await invitationManager.respondToRemoteInvitation(
                                id: invite.id,
                                accepted: true,
                                activity: invite.activity,
                                startTime: invite.startTime,
                                endTime: invite.endTime,
                                fromIdentifier: invite.fromIdentifier
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
                                fromIdentifier: invite.fromIdentifier
                            )
                            await upcomingEventsViewModel.refresh()
                        }
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

    @ViewBuilder
    private func tabLabel(_ title: String, systemImage: String, isActive: Bool) -> some View {
        Label {
            Text(title)
                .foregroundStyle(isActive ? AnyShapeStyle(EtaColor.warm) : AnyShapeStyle(EtaColor.text2))
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(
                    isActive
                        ? AnyShapeStyle(EtaColor.appGradient)
                        : AnyShapeStyle(EtaColor.text2)
                )
        }
    }
}
