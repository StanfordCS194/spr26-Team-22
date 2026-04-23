import Foundation

/// A single generated hangout suggestion.
/// Produced by SuggestionService; displayed in SuggestionView and handed to InviteService.
struct Suggestion {
    var contact: TrackedContact
    var activity: Activity
    /// Human-readable rationale shown to the user, e.g. "You haven't hung out in 3 weeks".
    var reason: String
    var generatedAt: Date
}
