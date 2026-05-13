import Foundation

/// Produces plain-English ContextFacts from a single data domain.
///
/// Each concrete implementation reads from one backing store (event history,
/// feedback entries, onboarding preferences) and converts raw data into
/// human-readable facts suitable for embedding into an LLM prompt.
///
/// Facts are derived on demand — no caching. DefaultContextEngine fans out
/// to all registered sources in parallel.
protocol ContextSource {
    /// Returns facts specific to the relationship between the user and the given contact.
    func facts(for contact: TrackedContact) async throws -> [ContextFact]

    /// Returns user-level goals and preferences that apply regardless of contact.
    func userGoals() async throws -> [ContextFact]
}
