import Foundation

/// Selects a hangout activity using deterministic rules.
///
/// Picks a random activity from the hardcoded Activity enum pool and produces
/// a reason string derived from the contact's relationship health score.
/// Context (PromptContext) is intentionally ignored — the rules path does not
/// require LLM or historical context to function.
///
/// ActivityType = Activity (the structured enum). The enum value is erased to
/// its description String before constructing ActivityProposal.
final class RulesActivityStrategy: ActivityStrategy {
    typealias ActivityType = Activity

    func propose(
        for health: RelationshipHealth,
        context: PromptContext
    ) async throws -> ActivityProposal? {
        guard let activity = Activity.allCases.randomElement() else { return nil }
        return ActivityProposal(
            activityDescription: activity.description,
            reason: reason(for: health)
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
