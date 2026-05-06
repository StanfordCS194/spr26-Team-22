import Foundation

/// Aggregates context from all registered ContextSources into a single PromptContext
/// for a given contact.
///
/// Facts are derived lazily on every call — no caching, no pre-computation.
/// Callers never interact with individual ContextSources directly.
///
/// Today: DefaultContextEngine (fans out to [any ContextSource] in parallel).
/// Tomorrow: a caching or summarisation layer can be added by introducing a new conformer.
protocol ContextEngine {
    /// Returns all context relevant to generating a suggestion for the given contact.
    /// Includes both contact-specific relationship facts and user-level goals.
    func query(for contact: TrackedContact) async throws -> PromptContext
}
