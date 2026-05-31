import Foundation

/// Derives relationship facts from Eta's scheduled hangout history via RelationshipService.
///
/// Converts computed RelationshipHealth data into plain-English ContextFacts:
/// days since last hangout, hangout frequency, and the most recent event title.
final class EventHistoryContextSource: ContextSource {
    private let relationshipService: RelationshipService

    init(relationshipService: RelationshipService) {
        self.relationshipService = relationshipService
    }

    func facts(for contact: TrackedContact) async throws -> [ContextFact] {
        let allHealth = await relationshipService.computeHealth()
        guard let health = allHealth.first(where: { $0.contact.id == contact.id }) else { return [] }

        var facts: [ContextFact] = []

        if let days = health.daysSinceLastHangout {
            facts.append(ContextFact(
                description: "You last hung out with \(contact.givenName) \(days) day(s) ago",
                source: .eventHistory
            ))
        } else {
            facts.append(ContextFact(
                description: "You have no recorded hangouts with \(contact.givenName) yet",
                source: .eventHistory
            ))
        }

        if health.hangoutCount > 0 {
            facts.append(ContextFact(
                description: "You've hung out with \(contact.givenName) \(health.hangoutCount) time(s) in the last 90 days",
                source: .eventHistory
            ))
        }

        if let title = health.lastHangoutTitle {
            facts.append(ContextFact(
                description: "Your most recent hangout with \(contact.givenName) was: \(title)",
                source: .eventHistory
            ))
        }

        let tags = contact.contextTags
        if !tags.isEmpty {
            let tagList = tags.map(\.displayName).joined(separator: ", ")
            facts.append(ContextFact(
                description: "Your relationship context with \(contact.givenName): \(tagList)",
                source: .eventHistory
            ))
        }

        return facts
    }

    func userGoals() async throws -> [ContextFact] {
        // Event history has no user-level goals to contribute.
        return []
    }
}
