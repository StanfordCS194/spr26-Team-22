import Foundation

/// Generates a hangout suggestion by combining two signals:
/// 1. Opportunity — a free slot in the user's near-term calendar (via CalendarDataProvider)
/// 2. Need       — a contact whose relationship health score is above the recency threshold
///
/// Both signals must be present. If either is absent, generateSuggestion() returns nil
/// and the For You inbox remains empty.
///
/// Contact selection (the "need" half) is handled inline here — health score ranking
/// is stable rules logic that does not need to be swapped independently.
/// Activity and reason selection is delegated to the injected ActivityStrategy.
///
/// SuggestionService depends on CalendarDataProvider concretely (not via a protocol)
/// for free slot detection, since that capability is distinct from ImplicitDataProvider's
/// historical event fetching and no second implementation is anticipated. See CLAUDE.md.
final class SuggestionService {
    private let calendar: CalendarDataProvider
    private let relationshipService: RelationshipService
    private let contextEngine: any ContextEngine
    private let activityStrategy: any ActivityStrategy
    private let fallbackStrategy: RulesActivityStrategy

    /// Contacts with a health score below this threshold are considered "recently seen"
    /// and do not qualify for a suggestion. 7.0 corresponds to roughly one week.
    private let minimumScoreThreshold: Double = 7

    init(
        calendar: CalendarDataProvider,
        relationshipService: RelationshipService,
        contextEngine: any ContextEngine,
        activityStrategy: any ActivityStrategy,
        fallbackStrategy: RulesActivityStrategy
    ) {
        self.calendar = calendar
        self.relationshipService = relationshipService
        self.contextEngine = contextEngine
        self.activityStrategy = activityStrategy
        self.fallbackStrategy = fallbackStrategy
    }

    /// Returns a Suggestion when both a free slot and an overdue contact exist,
    /// nil otherwise. Uses all user preferences for calendar window, activity filtering,
    /// and relationship health thresholds.
    func generateSuggestion() async -> Suggestion? {
        // Signal 1: opportunity. Check first — synchronous and cheap.
        guard let freeSlot = calendar.findFreeSlot() else {
            return nil
        }

        // Signal 2: need. Rank contacts by health score.
        let healthScores = await relationshipService.computeHealth()
        guard let topHealth = topContact(from: healthScores) else {
            return nil
        }

        // Fetch context for the chosen contact. Failures produce empty context rather
        // than aborting — a suggestion without context is better than no suggestion.
        let context = (try? await contextEngine.query(for: topHealth.contact)) ?? .empty

        // Delegate activity and reason selection to the strategy.
        // On LLM failure, fall back to the rules-based strategy so the inbox isn't left empty.
        let proposal: ActivityProposal
        do {
            if let proposalAttempt = try await activityStrategy.propose(for: topHealth, context: context) {
                proposal = proposalAttempt
            } else if let fallback = try await fallbackStrategy.propose(for: topHealth, context: context) {
                proposal = fallback
            } else {
                return nil
            }
        } catch {
            print(error.localizedDescription)
            guard let fallback = try? await fallbackStrategy.propose(for: topHealth, context: context) else {
                return nil
            }
            proposal = fallback
        }

        return Suggestion(
            contact: topHealth.contact,
            activityDescription: proposal.activityDescription,
            reason: proposal.reason,
            proposedTime: freeSlot,
            generatedAt: .now
        )
    }

    // MARK: - Private

    /// Returns the most overdue active contact above the score threshold, or nil if none qualifies.
    private func topContact(from healthScores: [RelationshipHealth]) -> RelationshipHealth? {
        healthScores
            .filter { $0.contact.isActive && $0.score >= minimumScoreThreshold }
            .max(by: { $0.score < $1.score })
    }
}
