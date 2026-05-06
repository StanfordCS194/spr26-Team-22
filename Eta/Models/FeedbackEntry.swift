import Foundation
import SwiftData

/// A single explicit feedback data point recorded after a hangout.
///
/// Stores a verdict (positive/negative) for a specific activity with a specific contact.
/// FeedbackContextSource converts these entries into plain-English ContextFacts
/// that the LLM can use to personalise future suggestions.
///
/// contactID is stored as a plain UUID (no SwiftData relationship) to avoid cascade
/// complexity — contacts may be deleted independently of their feedback history.
@Model
final class FeedbackEntry {
    var id: UUID
    /// The UUID of the TrackedContact this feedback is about.
    var contactID: UUID
    /// The activity that was done — free-form string to support both enum and LLM-generated activities.
    var activityDescription: String
    /// true = the user would do this activity with this contact again; false = they wouldn't.
    var verdict: Bool
    var date: Date

    init(
        id: UUID = UUID(),
        contactID: UUID,
        activityDescription: String,
        verdict: Bool,
        date: Date = .now
    ) {
        self.id = id
        self.contactID = contactID
        self.activityDescription = activityDescription
        self.verdict = verdict
        self.date = date
    }
}
