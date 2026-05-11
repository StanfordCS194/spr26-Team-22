import Foundation

/// The output of an ActivityStrategy: an activity description and a reason string.
///
/// Both structured (Activity enum) and unstructured (LLM-generated String) strategies
/// erase their internal ActivityType to a plain String here.
/// SuggestionService assembles a full Suggestion by adding contact, proposedTime, and generatedAt.
struct ActivityProposal {
    /// Plain-English activity description ready for display, e.g. "Grab coffee" or "Go rock climbing".
    var activityDescription: String
    /// Human-readable rationale shown to the user, e.g. "You haven't hung out in 3 weeks".
    var reason: String
}
