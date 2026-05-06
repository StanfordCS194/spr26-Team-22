import Foundation

/// A single generated hangout suggestion.
/// Produced by SuggestionService; displayed in SuggestionView and handed to InviteService.
struct Suggestion {
    var contact: TrackedContact
    /// Plain-English activity description — may be a structured enum rawValue ("Grab coffee")
    /// or a free-form LLM-generated string ("Go rock climbing at the gym").
    var activityDescription: String
    /// Human-readable rationale shown to the user, e.g. "You haven't hung out in 3 weeks".
    var reason: String
    /// The specific free calendar slot that triggered this suggestion.
    var proposedTime: DateInterval
    var generatedAt: Date
}
