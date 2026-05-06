import Foundation

/// The data domain that produced a ContextFact.
/// Used for debugging and potential future source-based filtering.
enum ContextFactSource {
    case eventHistory
    case explicitFeedback
    case onboardingPreferences
    case userGoal
}

/// A single plain-English observation about the user or their relationship with a contact.
/// Designed to be embedded directly into an LLM prompt with no further transformation.
///
/// Example: "You last hung out with Jason 21 days ago"
///          "You rated 'Grab coffee' with Jason positively on Apr 10, 2026"
struct ContextFact {
    /// Plain-English description, embeddable directly into a prompt line.
    var description: String
    /// Which data domain produced this fact.
    var source: ContextFactSource
}

/// All context relevant to generating an activity suggestion for a specific contact.
/// Produced by ContextEngine; consumed by ActivityStrategy conformers.
struct PromptContext {
    /// Facts specific to the (user, contact) relationship — hangout history, feedback, etc.
    var relationshipFacts: [ContextFact]
    /// User-level goals and preferences that apply regardless of the contact.
    var userGoals: [ContextFact]

    static let empty = PromptContext(relationshipFacts: [], userGoals: [])
}
