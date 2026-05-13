import Foundation

/// Derives relationship facts from per-contact preferences and generated insights.
///
/// Surfaces three categories of contact-specific context into the LLM prompt:
///   1. User-confirmed liked/disliked activities for this person.
///   2. Free-text notes the user has written about this contact.
///   3. Recent undismissed insight headlines generated for this contact
///      (e.g. drift warnings, pattern observations) — capped at 2 so the
///      prompt doesn't get flooded.
final class InsightsContextSource: ContextSource {
    private let contactProfileService: ContactProfileService
    private let insightRepository: PersonalRelationshipInsightRepository

    init(
        contactProfileService: ContactProfileService,
        insightRepository: PersonalRelationshipInsightRepository
    ) {
        self.contactProfileService = contactProfileService
        self.insightRepository = insightRepository
    }

    func facts(for contact: TrackedContact) async throws -> [ContextFact] {
        var facts: [ContextFact] = []

        let profile = contactProfileService.profile(for: contact)

        if !profile.likedActivities.isEmpty {
            let list = profile.likedActivities.map(\.rawValue).joined(separator: ", ")
            facts.append(ContextFact(
                description: "You and \(contact.givenName) enjoy: \(list)",
                source: .contactInsights
            ))
        }

        if !profile.dislikedActivities.isEmpty {
            let list = profile.dislikedActivities.map(\.rawValue).joined(separator: ", ")
            facts.append(ContextFact(
                description: "\(contact.givenName) doesn't enjoy these activities with you: \(list)",
                source: .contactInsights
            ))
        }

        let notes = profile.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            facts.append(ContextFact(
                description: "Notes about \(contact.givenName): \(notes)",
                source: .contactInsights
            ))
        }

        let allInsights = (try? insightRepository.fetchAll()) ?? []
        let contactInsights = allInsights.filter {
            $0.friendID == contact.id && !$0.isDismissed
        }
        for insight in contactInsights.prefix(2) {
            facts.append(ContextFact(
                description: insight.headline,
                source: .contactInsights
            ))
        }

        return facts
    }

    func userGoals() async throws -> [ContextFact] {
        return []
    }
}
