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
    // Must be held strongly — UNUserNotificationCenter.delegate is weak.
    private let notificationDelegate: NotificationDelegate
    private let upcomingEventsViewModel: UpcomingEventsViewModel
    private let availabilityViewModel: AvailabilityViewModel
    private let analyticsService: AnalyticsService
    private let photoRepository: ActivityPhotoRepository
    private let reminderPhotoState: ReminderPhotoState
    private let nudgeService: NudgeService
    private let nudgeScheduler: NudgeScheduler
    private let weeklyCheckInService: WeeklyCheckInService
    private let weeklyCheckInState: WeeklyCheckInState
    private let nudgeReminderState: NudgeReminderState
    @State private var onboardingViewModel: OnboardingViewModel

    init() {
        let container = try! ModelContainer(
            for: TrackedContact.self,
                ScheduledHangout.self,
                AnalyticsEvent.self,
                Invitation.self,
                ActivityPhoto.self,
                Goal.self,
                PersonalRelationshipInsight.self,
                ContactProfile.self
        )
        self.container = container

        let ctx = container.mainContext
        let repository = ContactRepository(modelContext: ctx)
        let hangoutRepository = ScheduledHangoutRepository(modelContext: ctx)
        let photoRepository = ActivityPhotoRepository(modelContext: ctx)
        self.photoRepository = photoRepository
        let reminderPhotoState = ReminderPhotoState()
        self.reminderPhotoState = reminderPhotoState
        let goalRepository = GoalRepository(modelContext: ctx)
        let insightRepository = PersonalRelationshipInsightRepository(modelContext: ctx)

        let analyticsService = AnalyticsService(modelContext: ctx)
        self.analyticsService = analyticsService
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
        relationshipService.setAnalyticsService(analyticsService)
        let nudgeService = NudgeService(
            relationshipService: relationshipService,
            photoRepository: photoRepository,
            runner: GitHubModelsLLMRunner()
        )
        self.nudgeService = nudgeService
        self.weeklyCheckInService = WeeklyCheckInService()
        let weeklyCheckInState = WeeklyCheckInState()
        self.weeklyCheckInState = weeklyCheckInState
        let nudgeReminderState = NudgeReminderState()
        self.nudgeReminderState = nudgeReminderState

        let profileRepository = ContactProfileRepository(modelContext: ctx)
        let contactProfileService = ContactProfileService(profileRepository: profileRepository)

        // Context engine — fans out to all data sources in parallel on each query.
        let contextEngine = DefaultContextEngine(sources: [
            EventHistoryContextSource(relationshipService: relationshipService),
            PreferencesContextSource(preferencesService: preferencesService),
            InsightsContextSource(contactProfileService: contactProfileService, insightRepository: insightRepository)
        ])

        // Activity strategy — chooses an activity
        let activityStrategy = LLMActivityStrategy(runner: GitHubModelsLLMRunner())
        let suggestionService = SuggestionService(
            availabilityProvider: availabilityDataProvider,
            relationshipService: relationshipService,
            contextEngine: contextEngine,
            activityStrategy: activityStrategy
        )
        let inviteProvider = iMessageInviteProvider()
        let inviteService = InviteService(
            provider: inviteProvider,
            hangoutRepository: hangoutRepository
        )

        let notificationService = LocalNotificationService(preferencesService: preferencesService)
        let invitationManager = InvitationManager(
            notificationService: notificationService,
            modelContext: ctx
        )
        self.nudgeScheduler = NudgeScheduler(calendarDataProvider: calendarDataProvider)
        let notificationDelegate = NotificationDelegate(
            invitationManager: invitationManager,
            reminderPhotoState: reminderPhotoState,
            weeklyCheckInState: weeklyCheckInState,
            nudgeReminderState: nudgeReminderState
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
        self.suggestionViewModel = SuggestionViewModel(
            suggestionService: suggestionService,
            inviteService: inviteService,
            invitationManager: invitationManager,
            formatter: formatter,
            photoRepository: photoRepository
        )
        self.upcomingEventsViewModel = UpcomingEventsViewModel(
            hangoutRepository: hangoutRepository,
            formatter: formatter
        )
        self.availabilityViewModel = AvailabilityViewModel(
            repository: availabilityRepository,
            hangoutRepository: hangoutRepository,
            activityDurationSettings: activityDurationSettings
        )
        self.homeViewModel = HomeViewModel(
            goalRepository: goalRepository,
            insightGenerationService: insightGenerationService,
            goalTrackingService: goalTrackingService,
            contactRepository: repository,
            hangoutRepository: hangoutRepository,
            formatter: formatter,
            relationshipService: relationshipService,
            contactProfileService: contactProfileService
        )

        let seeder = MockDataSeeder(modelContext: ctx)

        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            seeder.seedIfNeeded()
        }

        self._onboardingViewModel = State(initialValue: OnboardingViewModel(
            preferencesService: preferencesService,
            onComplete: { seeder.seedIfNeeded() }
        ))

        setupLifecycleTracking(analyticsService: analyticsService)
    }

    var body: some Scene {
        WindowGroup {
            if onboardingViewModel.hasCompletedOnboarding {
                MainTabView(
                    homeViewModel: homeViewModel,
                    connectionsViewModel: connectionsViewModel,
                    suggestionViewModel: suggestionViewModel,
                    upcomingEventsViewModel: upcomingEventsViewModel,
                    availabilityViewModel: availabilityViewModel,
                    analyticsService: analyticsService,
                    photoRepository: photoRepository,
                    reminderPhotoState: reminderPhotoState,
                    nudgeService: nudgeService,
                    nudgeScheduler: nudgeScheduler,
                    weeklyCheckInService: weeklyCheckInService,
                    weeklyCheckInState: weeklyCheckInState,
                    nudgeReminderState: nudgeReminderState
                )
            } else {
                OnboardingView(viewModel: onboardingViewModel)
            }
        }
        .modelContainer(container)
    }

    private func setupLifecycleTracking(analyticsService: AnalyticsService) {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            analyticsService.logAppBackgrounded()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            analyticsService.logAppForegrounded()
            Task { await nudgeService.scheduleNudge() }
            Task { await weeklyCheckInService.scheduleIfNeeded() }
        }
    }
}
