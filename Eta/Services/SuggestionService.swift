import Foundation

/// Generates a hangout suggestion by combining two signals:
/// 1. Opportunity — a free slot in the user's near-term calendar (via CalendarDataProvider)
/// 2. Need       — a contact whose relationship health score is above the recency threshold
///
/// Both signals must be present. If either is absent, generateSuggestion() returns nil
/// and the For You inbox remains empty.
///
/// SuggestionService depends on CalendarDataProvider concretely (not via a protocol)
/// for free slot detection, since that capability is distinct from ImplicitDataProvider's
/// historical event fetching and no second implementation is anticipated. See CLAUDE.md.
final class SuggestionService {
    private let calendar: CalendarDataProvider
    private let relationshipService: RelationshipService
    private let strategy: any SuggestionStrategy

    init(
        calendar: CalendarDataProvider,
        relationshipService: RelationshipService,
        strategy: any SuggestionStrategy
    ) {
        self.calendar = calendar
        self.relationshipService = relationshipService
        self.strategy = strategy
    }

    /// Returns a Suggestion when both a free slot and an overdue contact exist,
    /// nil otherwise.
    func generateSuggestion() async -> Suggestion? {
        // Signal 1: opportunity. Check first — it's synchronous and cheap.
        guard let freeSlot = calendar.findFreeSlot() else { return nil }

        // Signal 2: need. Fetch health scores and let the strategy decide.
        let healthScores = await relationshipService.computeHealth()
        guard var suggestion = strategy.suggest(from: healthScores) else { return nil }

        // Attach the real free slot. The strategy sets a throwaway proposedTime
        // because it has no knowledge of calendar availability.
        suggestion.proposedTime = freeSlot
        return suggestion
    }
}
