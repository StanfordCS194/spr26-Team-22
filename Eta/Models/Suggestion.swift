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
    /// User-entered availability options that triggered this suggestion.
    var proposedTimes: [DateInterval] //Allow for later invitee choice of time
    var generatedAt: Date

    /// The default time used by the current scheduling flow.
    /// The invite message can still present multiple proposedTimes for later choice.
    var proposedTime: DateInterval {
        proposedTimes[0]
    }
}
