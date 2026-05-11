import Foundation

/// Selects an activity and produces a reason string for a pre-chosen contact.
///
/// The associated type declares what representation the strategy works with internally:
///   - RulesActivityStrategy uses Activity (the structured enum)
///   - LLMActivityStrategy  uses String    (free-form, LLM-generated)
///
/// Both conformers erase to activityDescription: String before returning ActivityProposal,
/// so SuggestionService and everything above it remain free of generic constraints.
///
/// Contact selection (who to suggest) is not this protocol's responsibility —
/// SuggestionService picks the top-scoring contact and passes RelationshipHealth in.
protocol ActivityStrategy {
    associatedtype ActivityType: ActivityRepresentable

    /// Returns an ActivityProposal for the given contact and context, or nil if no
    /// suitable activity can be determined (e.g. LLM unavailable, empty context).
    func propose(
        for health: RelationshipHealth,
        context: PromptContext
    ) async throws -> ActivityProposal?
}
