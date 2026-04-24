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
        case scheduled(timeLabel: String)
    }

    private(set) var suggestion: Suggestion?
    private(set) var isLoading: Bool = false
    private(set) var scheduleState: ScheduleState = .idle

    private let suggestionService: SuggestionService
    private let inviteService: InviteService
    private let formatter: ContactFormatter

    init(
        suggestionService: SuggestionService,
        inviteService: InviteService,
        formatter: ContactFormatter
    ) {
        self.suggestionService = suggestionService
        self.inviteService = inviteService
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
    }

    /// Clears the current suggestion. The inbox will show its empty state until
    /// the next refresh() call recomputes from scratch.
    func dismiss() {
        suggestion = nil
    }

    /// Persists the hangout, creates a calendar event, then drives the confirmation
    /// UI through accepted → scheduled states.
    func schedule() {
        guard let suggestion else { return }
        let label = timeLabel(for: suggestion)
        inviteService.book(suggestion: suggestion)
        Task { @MainActor in
            scheduleState = .accepted
            try? await Task.sleep(for: .seconds(1.2))
            scheduleState = .scheduled(timeLabel: label)
        }
    }

    /// Opens Messages with the pre-filled invite, then clears the confirmation state.
    func finishAndSend() {
        guard let suggestion else { return }
        inviteService.sendMessage(for: suggestion)
        self.suggestion = nil
        scheduleState = .idle
    }
}
