import Foundation

/// Drives SuggestionView.
///
/// Scene phase is observed in SuggestionView (via @Environment(\.scenePhase)),
/// not here — keeping this ViewModel free of SwiftUI and UIKit imports.
/// The View calls refresh() from .onChange(of: scenePhase) when the scene becomes .active.
@Observable
final class SuggestionViewModel {
    private(set) var suggestion: Suggestion?
    private(set) var isLoading: Bool = false

    private let suggestionService: SuggestionService
    private let formatter: ContactFormatter

    init(suggestionService: SuggestionService, formatter: ContactFormatter) {
        self.suggestionService = suggestionService
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
            df.dateFormat = "EEEE" // e.g. "Wednesday"
            return "\(df.string(from: start)) \(timeOfDay)"
        }
    }

    // MARK: - Actions

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        suggestion = await suggestionService.generateSuggestion()
    }

    /// Clears the current suggestion. The inbox will show its empty state until
    /// the next refresh() call recomputes from scratch.
    func dismiss() {
        suggestion = nil
    }
}
