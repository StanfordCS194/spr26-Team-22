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
        self.connectionsViewModel = ConnectionsViewModel(
            repository: repository,
            formatter: formatter,
            relationshipService: relationshipService
        )
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(connectionsViewModel: connectionsViewModel)
        }
        .modelContainer(container)
    }
}
