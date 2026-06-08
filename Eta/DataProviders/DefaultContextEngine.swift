import Foundation

/// Aggregates context from all registered ContextSources by fanning out queries in parallel.
///
/// Facts are derived lazily on every call — no caching or pre-computation.
/// Add a new data domain by injecting an additional ContextSource at construction time;
/// no changes to this class or anything above it are required.
final class DefaultContextEngine: ContextEngine {
    private let sources: [any ContextSource]

    init(sources: [any ContextSource]) {
        self.sources = sources
    }

    func query(for contact: TrackedContact) async throws -> PromptContext {
        var relationshipFacts: [ContextFact] = []
        var userGoals: [ContextFact] = []

        try await withThrowingTaskGroup(
            of: (relationship: [ContextFact], goals: [ContextFact]).self
        ) { group in
            for source in sources {
                group.addTask {
                    let facts = try await source.facts(for: contact)
                    let goals = try await source.userGoals()
                    return (facts, goals)
                }
            }
            for try await result in group {
                relationshipFacts.append(contentsOf: result.relationship)
                userGoals.append(contentsOf: result.goals)
            }
        }

        return PromptContext(relationshipFacts: relationshipFacts, userGoals: userGoals, previouslySuggestedActivities: [])
    }
}
