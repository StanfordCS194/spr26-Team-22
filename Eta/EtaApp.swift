//
//  EtaApp.swift
//  Eta
//
//  Created by Nick Riedman on 4/20/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct EtaApp: App {
    private let container: ModelContainer
    private let connectionsViewModel: ConnectionsViewModel
    private let suggestionViewModel: SuggestionViewModel
    private let homeViewModel: HomeViewModel
    private let settingsViewModel: SettingsViewModel
    // Must be held strongly — UNUserNotificationCenter.delegate is weak.
    private let notificationDelegate: NotificationDelegate
    private let invitationManager: InvitationManager
    private let upcomingEventsViewModel: UpcomingEventsViewModel
    private let availabilityViewModel: AvailabilityViewModel
    private let analyticsService: AnalyticsService
    private let photoRepository: ActivityPhotoRepository
    private let reminderPhotoState: ReminderPhotoState
    private let supabaseService: SupabaseService
    private let phoneSetupService: PhoneSetupService
    @State private var hasPhoneSetup: Bool
    private let nudgeService: NudgeService
    private let nudgeScheduler: NudgeScheduler
    private let weeklyCheckInService: WeeklyCheckInService
    private let weeklyCheckInState: WeeklyCheckInState
    private let nudgeReminderState: NudgeReminderState
    private let receivedInviteState: ReceivedInviteState
    private let chatViewModel: ChatViewModel
    @State private var onboardingViewModel: OnboardingViewModel
    private final class TimerBox { var timer: Timer? }
    private let pollTimerBox = TimerBox()

    init() {
        let container = try! ModelContainer(
            for: TrackedContact.self,
                ScheduledHangout.self,
                Invitation.self,
                Goal.self,
                PersonalRelationshipInsight.self,
                ContactProfile.self,
                ActivityPhoto.self,
                HangoutFeedback.self,
                PendingReceivedInvitation.self
        )
        self.container = container

        let ctx = container.mainContext
        let repository = ContactRepository(modelContext: ctx)
        let hangoutRepository = ScheduledHangoutRepository(modelContext: ctx)
        let goalRepository = GoalRepository(modelContext: ctx)
        let insightRepository = PersonalRelationshipInsightRepository(modelContext: ctx)
        let photoRepository = ActivityPhotoRepository(modelContext: container.mainContext)
        
        self.photoRepository = photoRepository
        let reminderPhotoState = ReminderPhotoState()
        self.reminderPhotoState = reminderPhotoState

        let supabaseService = SupabaseService()
        self.supabaseService = supabaseService

        let analyticsService = AnalyticsService(supabaseService: supabaseService)
        self.analyticsService = analyticsService
        let phoneSetupService = PhoneSetupService()
        self.phoneSetupService = phoneSetupService
        self._hasPhoneSetup = State(initialValue: phoneSetupService.myIdentifier != nil)
        if let id = phoneSetupService.myIdentifier {
            analyticsService.start(identifier: id)
        }

        let formatter = ContactFormatter()
        let preferencesService = PreferencesService()
        let availabilityRepository = UserDefaultsAvailabilityRepository()
        let activityDurationSettings = ActivityDurationSettings()
        let availabilityDataProvider = AvailabilityDataProvider(
            repository: availabilityRepository,
            hangoutRepository: hangoutRepository,
            activityDurationSettings: activityDurationSettings
        )

        let relationshipService = RelationshipService(
            repository: repository,
            hangoutRepository: hangoutRepository,
            preferencesService: preferencesService
        )
        let nudgeService = NudgeService(
            relationshipService: relationshipService,
            photoRepository: photoRepository,
            runner: GitHubModelsLLMRunner()
        )
        self.nudgeService = nudgeService
        self.weeklyCheckInService = WeeklyCheckInService(preferencesService: preferencesService)
        let weeklyCheckInState = WeeklyCheckInState()
        self.weeklyCheckInState = weeklyCheckInState
        let nudgeReminderState = NudgeReminderState()
        self.nudgeReminderState = nudgeReminderState
        let receivedInviteState = ReceivedInviteState()
        self.receivedInviteState = receivedInviteState

        let profileRepository = ContactProfileRepository(modelContext: ctx)
        let contactProfileService = ContactProfileService(profileRepository: profileRepository)
        let feedbackRepository = HangoutFeedbackRepository(modelContext: ctx)

        // Context engine — fans out to all data sources in parallel on each query.
        let contextEngine = DefaultContextEngine(sources: [
            EventHistoryContextSource(relationshipService: relationshipService),
            PreferencesContextSource(preferencesService: preferencesService),
            InsightsContextSource(contactProfileService: contactProfileService, insightRepository: insightRepository),
            HangoutFeedbackContextSource(feedbackRepository: feedbackRepository, hangoutRepository: hangoutRepository)
        ])

        // Activity strategy — chooses an activity; falls back to rules if LLM fails
        let activityStrategy = LLMActivityStrategy(runner: GitHubModelsLLMRunner())
        let fallbackStrategy = RulesActivityStrategy(profileService: contactProfileService)
        let suggestionService = SuggestionService(
            availabilityProvider: availabilityDataProvider,
            relationshipService: relationshipService,
            contextEngine: contextEngine,
            activityStrategy: activityStrategy,
            fallbackStrategy: fallbackStrategy,
            preferencesService: preferencesService
        )
        let inviteProvider = iMessageInviteProvider()
        let inviteService = InviteService(
            provider: inviteProvider,
            hangoutRepository: hangoutRepository
        )

        let notificationService = LocalNotificationService(preferencesService: preferencesService)
        let pendingReceivedInviteRepo = PendingReceivedInvitationRepository(modelContext: ctx)
        let invitationManager = InvitationManager(
            notificationService: notificationService,
            modelContext: ctx,
            supabaseService: supabaseService,
            phoneSetupService: phoneSetupService,
            pendingReceivedRepo: pendingReceivedInviteRepo,
            analyticsService: analyticsService
        )
        self.invitationManager = invitationManager
        invitationManager.receivedInviteState = receivedInviteState
        self.nudgeScheduler = NudgeScheduler(availabilityDataProvider: availabilityDataProvider)
        let notificationDelegate = NotificationDelegate(
            invitationManager: invitationManager,
            reminderPhotoState: reminderPhotoState,
            weeklyCheckInState: weeklyCheckInState,
            nudgeReminderState: nudgeReminderState,
            receivedInviteState: receivedInviteState
        )
        UNUserNotificationCenter.current().delegate = notificationDelegate
        self.notificationDelegate = notificationDelegate

        let insightGenerationService = InsightGenerationService(
            insightRepository: insightRepository,
            hangoutRepository: hangoutRepository,
            contactRepository: repository,
            profileRepository: profileRepository
        )
        let goalTrackingService = GoalTrackingService(
            goalRepository: goalRepository,
            hangoutRepository: hangoutRepository
        )

        self.connectionsViewModel = ConnectionsViewModel(
            repository: repository,
            formatter: formatter,
            relationshipService: relationshipService
        )
        self.chatViewModel = ChatViewModel(
            contactRepository: repository,
            inviteService: inviteService,
            invitationManager: invitationManager,
            availabilityDataProvider: availabilityDataProvider,
            goalRepository: goalRepository,
            analyticsService: analyticsService
        )
        self.suggestionViewModel = SuggestionViewModel(
            suggestionService: suggestionService,
            inviteService: inviteService,
            invitationManager: invitationManager,
            formatter: formatter,
            photoRepository: photoRepository,
            preferencesService: preferencesService
        )
        self.upcomingEventsViewModel = UpcomingEventsViewModel(
            hangoutRepository: hangoutRepository,
            pendingInviteRepository: pendingReceivedInviteRepo,
            invitationManager: invitationManager,
            inviteService: inviteService,
            contactRepository: repository,
            activityStrategy: activityStrategy,
            formatter: formatter
        )
        self.homeViewModel = HomeViewModel(
            goalRepository: goalRepository,
            insightGenerationService: insightGenerationService,
            goalTrackingService: goalTrackingService,
            contactRepository: repository,
            hangoutRepository: hangoutRepository,
            formatter: formatter,
            relationshipService: relationshipService,
            contactProfileService: contactProfileService,
            preferencesService: preferencesService,
            analyticsService: analyticsService
        )

        self.settingsViewModel = SettingsViewModel(
            preferencesService: preferencesService,
            weeklyCheckInService: weeklyCheckInService,
            onClearAll: {
                try? ctx.delete(model: TrackedContact.self)
                try? ctx.delete(model: ScheduledHangout.self)
                try? ctx.delete(model: Goal.self)
                try? ctx.delete(model: PersonalRelationshipInsight.self)
                try? ctx.delete(model: ContactProfile.self)
                try? ctx.delete(model: Invitation.self)
                try? ctx.save()
                UserDefaults.standard.removeObject(forKey: "insight_dismissal_counts")
            }
        )

        let seeder = MockDataSeeder(modelContext: ctx)

        // Returning users: seed is a no-op if data already exists.
        // First-time users: seed fires when they complete onboarding.
        // if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        //     seeder.seedIfNeeded()
        // }
        
        self.availabilityViewModel = AvailabilityViewModel(
            repository: availabilityRepository,
            hangoutRepository: hangoutRepository,
            activityDurationSettings: activityDurationSettings,
            analyticsService: analyticsService
        )

        self._onboardingViewModel = State(initialValue: OnboardingViewModel(
            preferencesService: preferencesService,
            onComplete: { analyticsService.logOnboardingCompleted() }
        ))

        setupLifecycleTracking(analyticsService: analyticsService)
    }

    var body: some Scene {
        WindowGroup {
            if !hasPhoneSetup {
                PhoneSetupView(phoneSetupService: phoneSetupService) {
                    hasPhoneSetup = true
                    if let id = phoneSetupService.myIdentifier {
                        analyticsService.start(identifier: id)
                        Task { await supabaseService.registerDevice(identifier: id) }
                    }
                }
            } else if onboardingViewModel.hasCompletedOnboarding {
                MainTabView(
                    homeViewModel: homeViewModel,
                    connectionsViewModel: connectionsViewModel,
                    suggestionViewModel: suggestionViewModel,
                    upcomingEventsViewModel: upcomingEventsViewModel,
                    settingsViewModel: settingsViewModel,
                    availabilityViewModel: availabilityViewModel,
                    analyticsService: analyticsService,
                    invitationManager: invitationManager,
                    photoRepository: photoRepository,
                    reminderPhotoState: reminderPhotoState,
                    nudgeService: nudgeService,
                    nudgeScheduler: nudgeScheduler,
                    weeklyCheckInService: weeklyCheckInService,
                    weeklyCheckInState: weeklyCheckInState,
                    nudgeReminderState: nudgeReminderState,
                    receivedInviteState: receivedInviteState,
                    chatViewModel: chatViewModel
                )
            } else {
                OnboardingView(viewModel: onboardingViewModel, analyticsService: analyticsService)
            }
        }
        .onOpenURL { url in
            guard url.scheme == "eta" else { return }
            invitationManager.handleInviteURL(url)
        }
        .modelContainer(container)
    }

    private func setupLifecycleTracking(analyticsService: AnalyticsService) {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [self] _ in
            analyticsService.logAppBackgrounded()
            pollTimerBox.timer?.invalidate()
            pollTimerBox.timer = nil
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [self] _ in
            analyticsService.logAppForegrounded()
            Task { await nudgeService.scheduleNudge() }
            Task { await weeklyCheckInService.scheduleIfNeeded() }
            Task { await invitationManager.pollForUpdates() }
            if let id = phoneSetupService.myIdentifier {
                Task { await supabaseService.registerDevice(identifier: id) }
            }
            pollTimerBox.timer?.invalidate()
            pollTimerBox.timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
                Task { await invitationManager.pollForUpdates() }
            }
        }

        registerInviteResponseCategory()
    }

    private func registerInviteResponseCategory() {
        let category = UNNotificationCategory(
            identifier: "INVITE_RESPONSE",
            actions: [],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
