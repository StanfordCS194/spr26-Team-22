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
    private let upcomingEventsViewModel: UpcomingEventsViewModel
    private let analyticsService: AnalyticsService
    @State private var onboardingViewModel: OnboardingViewModel

    init() {
        let container = try! ModelContainer(
            for: TrackedContact.self,
                ScheduledHangout.self,
                AnalyticsEvent.self,
                Invitation.self,
                Goal.self,
                PersonalRelationshipInsight.self,
                ContactProfile.self
        )
        self.container = container

        let ctx = container.mainContext
        let repository = ContactRepository(modelContext: ctx)
        let hangoutRepository = ScheduledHangoutRepository(modelContext: ctx)
        let goalRepository = GoalRepository(modelContext: ctx)
        let insightRepository = PersonalRelationshipInsightRepository(modelContext: ctx)

        let analyticsService = AnalyticsService(modelContext: ctx)
        self.analyticsService = analyticsService
        let formatter = ContactFormatter()
        let preferencesService = PreferencesService()
        let calendarDataProvider = CalendarDataProvider(preferencesService: preferencesService)

        let relationshipService = RelationshipService(
            providers: [calendarDataProvider],
            repository: repository,
            hangoutRepository: hangoutRepository,
            preferencesService: preferencesService
        )
        relationshipService.setAnalyticsService(analyticsService)

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
            calendar: calendarDataProvider,
            relationshipService: relationshipService,
            contextEngine: contextEngine,
            activityStrategy: activityStrategy
        )
        let inviteProvider = iMessageInviteProvider()
        let inviteService = InviteService(
            provider: inviteProvider,
            hangoutRepository: hangoutRepository,
            calendarDataProvider: calendarDataProvider
        )

        let notificationService = LocalNotificationService(preferencesService: preferencesService)
        let invitationManager = InvitationManager(
            notificationService: notificationService,
            modelContext: ctx
        )
        let notificationDelegate = NotificationDelegate(invitationManager: invitationManager)
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
            formatter: formatter
        )
        self.upcomingEventsViewModel = UpcomingEventsViewModel(
            hangoutRepository: hangoutRepository,
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
            preferencesService: preferencesService
        )

        self.settingsViewModel = SettingsViewModel(
            preferencesService: preferencesService,
            onClearAll: {
                try? ctx.delete(model: TrackedContact.self)
                try? ctx.delete(model: ScheduledHangout.self)
                try? ctx.delete(model: Goal.self)
                try? ctx.delete(model: PersonalRelationshipInsight.self)
                try? ctx.delete(model: ContactProfile.self)
                try? ctx.delete(model: AnalyticsEvent.self)
                try? ctx.delete(model: Invitation.self)
                try? ctx.save()
                UserDefaults.standard.removeObject(forKey: "insight_dismissal_counts")
                UserDefaults.standard.removeObject(forKey: "eta.sessionNotes")
            }
        )

        let seeder = MockDataSeeder(modelContext: ctx)

        // Returning users: seed is a no-op if data already exists.
        // First-time users: seed fires when they complete onboarding.
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
                    settingsViewModel: settingsViewModel,
                    analyticsService: analyticsService
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
        }
    }
}
