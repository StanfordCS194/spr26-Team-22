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

    init() {
        let container = try! ModelContainer(for: TrackedContact.self, ScheduledHangout.self, Invitation.self)
        self.container = container

        let repository = ContactRepository(modelContext: container.mainContext)
        let hangoutRepository = ScheduledHangoutRepository(modelContext: container.mainContext)
        let formatter = ContactFormatter()
        let calendarDataProvider = CalendarDataProvider()

        let relationshipService = RelationshipService(
            providers: [calendarDataProvider],
            repository: repository,
            hangoutRepository: hangoutRepository
        )
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

        let notificationService = LocalNotificationService()
        let invitationManager = InvitationManager(
            notificationService: notificationService,
            modelContext: container.mainContext
        )
        let notificationDelegate = NotificationDelegate(invitationManager: invitationManager)
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
