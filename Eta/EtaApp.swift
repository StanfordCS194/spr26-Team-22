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

    init() {
        let container = try! ModelContainer(for: TrackedContact.self)
        self.container = container

        let repository = ContactRepository(modelContext: container.mainContext)
        let formatter = ContactFormatter()
        let calendarDataProvider = CalendarDataProvider()

        let relationshipService = RelationshipService(
            providers: [calendarDataProvider],
            repository: repository
        )
        let rulesStrategy = RulesSuggestionStrategy()
        let suggestionService = SuggestionService(
            calendar: calendarDataProvider,
            relationshipService: relationshipService,
            strategy: rulesStrategy
        )

        self.connectionsViewModel = ConnectionsViewModel(
            repository: repository,
            formatter: formatter,
            relationshipService: relationshipService
        )
        self.suggestionViewModel = SuggestionViewModel(
            suggestionService: suggestionService,
            formatter: formatter
        )
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(
                connectionsViewModel: connectionsViewModel,
                suggestionViewModel: suggestionViewModel
            )
        }
        .modelContainer(container)
    }
}
