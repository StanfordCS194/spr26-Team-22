import SwiftUI

fileprivate enum TabChoice: Hashable {
    case friends, events, activites
}

struct MainTabView: View {
    let connectionsViewModel: ConnectionsViewModel
    let suggestionViewModel: SuggestionViewModel
    let upcomingEventsViewModel: UpcomingEventsViewModel
    let analyticsService: AnalyticsService
    let invitationManager: InvitationManager

    @State private var selectedTab: TabChoice = .events

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Friends", systemImage: "person.2", value: .friends) {
                ConnectionsView(
                    viewModel: connectionsViewModel,
                    analyticsService: analyticsService
                )
            }
            Tab("Events", systemImage: "cup.and.saucer", value: .events) {
                UpcomingEventsDashboard(viewModel: upcomingEventsViewModel)
            }
            Tab("Suggestions", systemImage: "sparkles", value: .activites) {
                SuggestionView(
                    viewModel: suggestionViewModel,
                    analyticsService: analyticsService
                )
            }
        }
        .analyticsDebug(service: analyticsService)
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
    }
}
