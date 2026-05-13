import Foundation

/// Drives SuggestionView.
///
/// Scene phase is observed in SuggestionView (via @Environment(\.scenePhase)),
/// not here — keeping this ViewModel free of SwiftUI and UIKit imports.
/// The View calls refresh() from .onChange(of: scenePhase) when the scene becomes .active.
@Observable
final class SuggestionViewModel {

    enum ScheduleState {
        case idle
        case accepted
        case invitationSent(friendName: String)
    }

    private(set) var suggestion: Suggestion?
    private(set) var isLoading: Bool = false
    private(set) var scheduleState: ScheduleState = .idle

    private let suggestionService: SuggestionService
    private let inviteService: InviteService
    private let invitationManager: InvitationManager
    private let formatter: ContactFormatter

    init(
        suggestionService: SuggestionService,
        inviteService: InviteService,
        invitationManager: InvitationManager,
        formatter: ContactFormatter
    ) {
        self.suggestionService = suggestionService
        self.inviteService = inviteService
        self.invitationManager = invitationManager
        self.formatter = formatter
    }

    // MARK: - Display

    func displayName(for suggestion: Suggestion) -> String {
        formatter.displayName(for: suggestion.contact)
    }

    /// Returns a natural-language description of when the proposed free slot falls,
    /// e.g. "this afternoon", "tomorrow morning", "Wednesday evening".
    func timeLabel(for suggestion: Suggestion) -> String {
        let start = suggestion.proposedTime.start
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let slotDay = cal.startOfDay(for: start)
        let dayOffset = cal.dateComponents([.day], from: today, to: slotDay).day ?? 0
        let hour = cal.component(.hour, from: start)

        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<18: timeOfDay = "afternoon"
        default:     timeOfDay = "evening"
        }

        switch dayOffset {
        case 0:  return "this \(timeOfDay)"
        case 1:  return "tomorrow \(timeOfDay)"
        default:
            let df = DateFormatter()
            df.dateFormat = "EEEE"
            return "\(df.string(from: start)) \(timeOfDay)"
        }
    }

    // MARK: - Actions

    func refresh() async {
        guard case .idle = scheduleState else { return }
        isLoading = true
        defer { isLoading = false }
        suggestion = await suggestionService.generateSuggestion()

        #if DEBUG
        if suggestion == nil {
            let demoContact = TrackedContact(
                cnContactIdentifier: "demo",
                name: "Alex Demo",
                givenName: "Alex",
                familyName: "Demo"
            )
            let start = Calendar.current.date(byAdding: .hour, value: 2, to: .now) ?? .now
            suggestion = Suggestion(
                contact: demoContact,
                activityDescription: "Grab coffee",
                reason: "You haven't hung out in a while.",
                proposedTime: DateInterval(start: start, duration: 3600),
                generatedAt: .now
            )
        }
        #endif
    }

    /// Clears the current suggestion. The inbox will show its empty state until
    /// the next refresh() call recomputes from scratch.
    func dismiss() {
        suggestion = nil
    }

    /// Persists the hangout, creates a calendar event, then sends the invitation
    /// via push notification. Drives the UI through accepted → invitationSent states.
    func schedule() {
        guard let suggestion else { return }
        let name = displayName(for: suggestion)
        let activityName = suggestion.activityDescription
        let scheduledTime = suggestion.proposedTime.start

        let hangoutID = inviteService.book(suggestion: suggestion)

        Task { @MainActor in
            scheduleState = .accepted
            _ = try? await invitationManager.acceptSuggestion(
                activityName: activityName,
                friendName: name,
                scheduledTime: scheduledTime,
                hangoutID: hangoutID
            )
            scheduleState = .invitationSent(friendName: name)
            self.suggestion = nil
        }
    }

    /// Returns the suggestion view to idle so the user can pull-to-refresh for a new suggestion.
    func done() {
        scheduleState = .idle
    }
}
