import Foundation

/// Selects a hangout suggestion from a ranked list of relationship health scores.
///
/// Returns nil when the highest-scoring active contact has a score below
/// the user's configured `relationshipHealthThreshold` — interpreted as "you've seen
/// everyone recently, no suggestion needed." This is the demand half of the
/// opportunity-and-demand gate; SuggestionService handles the opportunity half (free calendar slot).
///
/// The `proposedTime` in the returned Suggestion is a throwaway placeholder.
/// SuggestionService always overwrites it with the actual free slot before returning
/// to the caller — the strategy has no knowledge of calendar availability.
final class RulesSuggestionStrategy: SuggestionStrategy {
    private let preferencesService: PreferencesService

    init(preferencesService: PreferencesService) {
        self.preferencesService = preferencesService
    }

    func suggest(from healthScores: [RelationshipHealth]) -> Suggestion? {
        let minimumScoreThreshold = preferencesService.preferences.relationshipHealthThreshold
        
        guard let top = healthScores
            .filter({ $0.contact.isActive && $0.score >= minimumScoreThreshold })
            .max(by: { $0.score < $1.score })
        else { return nil }

        // Filter to user's preferred activities
        let preferredActivityNames = preferencesService.preferences.preferredActivities
        let availableActivities = Activity.allCases.filter { preferredActivityNames.contains($0.rawValue) }
        guard let activity = availableActivities.randomElement() else { return nil }

        return Suggestion(
            contact: top.contact,
            activity: activity,
            reason: reason(for: top),
            proposedTime: DateInterval(start: .now, duration: 3600), // overwritten by SuggestionService
            generatedAt: .now
        )
    }

    // MARK: - Private

    private func reason(for health: RelationshipHealth) -> String {
        guard let days = health.daysSinceLastHangout else {
            return "You two haven't hung out yet"
        }
        switch days {
        case 7..<14:
            return "You haven't hung out in over a week"
        case 14..<30:
            return "It's been \(days) days since your last hangout"
        default:
            return "You haven't hung out in over a month"
        }
    }
}
