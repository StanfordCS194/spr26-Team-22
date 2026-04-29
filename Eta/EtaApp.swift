//
//  EtaApp.swift
//  Eta
//
//  Created by Nick Riedman on 4/20/26.
//
import SwiftUI
import SwiftData

@main
struct EtaApp: App {
    private let container: ModelContainer
    private let connectionsViewModel: ConnectionsViewModel
    private let suggestionViewModel: SuggestionViewModel
    private let upcomingEventsViewModel: UpcomingEventsViewModel
    private let analyticsService: AnalyticsService
    private let repository: ContactRepository

    // Shared preferences service — injected into suggestion pipeline
    private let preferencesService = UserPreferencesService()

    init() {
        let container = try! ModelContainer(for: TrackedContact.self, ScheduledHangout.self, AnalyticsEvent.self)
        self.container = container

        let repository = ContactRepository(modelContext: container.mainContext)
        self.repository = repository
        let hangoutRepository = ScheduledHangoutRepository(modelContext: container.mainContext)
        let analyticsService = AnalyticsService(modelContext: container.mainContext)
        self.analyticsService = analyticsService

        let formatter = ContactFormatter()
        let calendarDataProvider = CalendarDataProvider()
        let relationshipService = RelationshipService(
            providers: [calendarDataProvider],
            repository: repository,
            hangoutRepository: hangoutRepository
        )
        relationshipService.setAnalyticsService(analyticsService)

        let rulesStrategy = RulesSuggestionStrategy()
        let suggestionService = SuggestionService(
            calendar: calendarDataProvider,
            relationshipService: relationshipService,
            strategy: rulesStrategy
        )

        let inviteProvider = iMessageInviteProvider()
        let inviteService = InviteService(
            provider: inviteProvider,
            hangoutRepository: hangoutRepository,
            calendarDataProvider: calendarDataProvider
        )

        self.connectionsViewModel = ConnectionsViewModel(
            repository: repository,
            formatter: formatter,
            relationshipService: relationshipService
        )
        self.suggestionViewModel = SuggestionViewModel(
            suggestionService: suggestionService,
            inviteService: inviteService,
            formatter: formatter
        )
        self.upcomingEventsViewModel = UpcomingEventsViewModel(
            hangoutRepository: hangoutRepository,
            formatter: formatter
        )

        setupLifecycleTracking(analyticsService: analyticsService)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(
                connectionsViewModel: connectionsViewModel,
                suggestionViewModel: suggestionViewModel,
                upcomingEventsViewModel: upcomingEventsViewModel,
                analyticsService: analyticsService
            )
            .environmentObject(preferencesService)
            .fullScreenCover(isPresented: .constant(!preferencesService.hasCompletedOnboarding)) {
                OnboardingView { preferences in
                    applyOnboardingPreferences(preferences)
                }
            }
        }
        .modelContainer(container)
    }

    // MARK: - Onboarding Completion

    private func applyOnboardingPreferences(_ preferences: OnboardingPreferences) {
        // 1. Persist activity prefs + frequency into UserPreferencesService
        preferencesService.apply(preferences)

        // 2. Seed selected contacts into the repository
        for contact in preferences.selectedContacts {
            // Adapt OnboardingContact → TrackedContact via your existing formatter/repository
            // Exact API depends on your ContactRepository — adjust as needed:
            repository.addContact(
                givenName: contact.givenName,
                familyName: contact.familyName,
                phoneNumber: contact.phoneNumber,
                externalID: contact.id,
                desiredFrequencyDays: contact.desiredFrequency?.days
                    ?? preferences.defaultFrequency.days
            )
        }

        // 3. Log onboarding complete for analytics
        analyticsService.logEvent("onboarding_completed", properties: [
            "activities_count": preferences.favoriteActivities.count,
            "contacts_count": preferences.selectedContacts.count,
            "default_frequency": preferences.defaultFrequency.rawValue,
        ])
    }

    private func setupLifecycleTracking(analyticsService: AnalyticsService) {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in analyticsService.logAppBackgrounded() }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in analyticsService.logAppForegrounded() }
    }
}