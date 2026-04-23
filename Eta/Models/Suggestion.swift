import Foundation

/// A single generated hangout suggestion.
/// Produced by SuggestionService; displayed in SuggestionView and handed to InviteService.
struct Suggestion {
    var contact: TrackedContact
    var activity: Activity
    /// Human-readable rationale shown to the user, e.g. "You haven't hung out in 3 weeks".
    var reason: String
    /// The specific free calendar slot that triggered this suggestion.
    /// Set by SuggestionService after the strategy picks the contact and activity.
    var proposedTime: DateInterval
    var generatedAt: Date
}
