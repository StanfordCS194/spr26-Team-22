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
    private let analyticsService: AnalyticsService

    init() {
        let container = try! ModelContainer(for: TrackedContact.self, ScheduledHangout.self, AnalyticsEvent.self)
        self.container = container

        let repository = ContactRepository(modelContext: container.mainContext)
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
        
        // Track app lifecycle events
        setupLifecycleTracking(analyticsService: analyticsService)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(
                connectionsViewModel: connectionsViewModel,
                suggestionViewModel: suggestionViewModel,
                analyticsService: analyticsService
            )
        }
        .modelContainer(container)
    }
    
    private func setupLifecycleTracking(analyticsService: AnalyticsService) {
        // Track app backgrounding/foregrounding
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
