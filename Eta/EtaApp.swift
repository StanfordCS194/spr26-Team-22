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
    // Must be held strongly — UNUserNotificationCenter.delegate is weak.
    private let notificationDelegate: NotificationDelegate
    private let upcomingEventsViewModel: UpcomingEventsViewModel
    private let analyticsService: AnalyticsService
    private let photoRepository: ActivityPhotoRepository
    private let reminderPhotoState: ReminderPhotoState
    @State private var onboardingViewModel: OnboardingViewModel

    init() {
        let container = try! ModelContainer(for: TrackedContact.self, ScheduledHangout.self, AnalyticsEvent.self, Invitation.self, ActivityPhoto.self)
        self.container = container

        let repository = ContactRepository(modelContext: container.mainContext)
        let hangoutRepository = ScheduledHangoutRepository(modelContext: container.mainContext)
        let photoRepository = ActivityPhotoRepository(modelContext: container.mainContext)
        self.photoRepository = photoRepository
        let reminderPhotoState = ReminderPhotoState()
        self.reminderPhotoState = reminderPhotoState

        let analyticsService = AnalyticsService(modelContext: container.mainContext)
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

        // Context engine — fans out to all data sources in parallel on each query.
        let contextEngine = DefaultContextEngine(sources: [
            EventHistoryContextSource(relationshipService: relationshipService),
            PreferencesContextSource(preferencesService: preferencesService)
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
            modelContext: container.mainContext
        )
        let notificationDelegate = NotificationDelegate(
            invitationManager: invitationManager,
            reminderPhotoState: reminderPhotoState
        )
        UNUserNotificationCenter.current().delegate = notificationDelegate
        self.notificationDelegate = notificationDelegate

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
        self._onboardingViewModel = State(initialValue: OnboardingViewModel(preferencesService: preferencesService))

        // Track app lifecycle events
        setupLifecycleTracking(analyticsService: analyticsService)
    }

    var body: some Scene {
        WindowGroup {
            if onboardingViewModel.hasCompletedOnboarding {
                MainTabView(
                    connectionsViewModel: connectionsViewModel,
                    suggestionViewModel: suggestionViewModel,
                    upcomingEventsViewModel: upcomingEventsViewModel,
                    analyticsService: analyticsService,
                    photoRepository: photoRepository,
                    reminderPhotoState: reminderPhotoState
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
