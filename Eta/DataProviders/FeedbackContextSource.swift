import Foundation

/// Derives relationship facts from explicit user feedback entries.
///
/// Converts stored FeedbackEntry records into plain-English ContextFacts:
/// e.g. "You rated 'Grab coffee' with Jason positively on Apr 10, 2026".
final class FeedbackContextSource: ContextSource {
    private let repository: FeedbackRepository
    private let dateFormatter: DateFormatter

    init(repository: FeedbackRepository) {
        self.repository = repository
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        self.dateFormatter = df
    }

    func facts(for contact: TrackedContact) async throws -> [ContextFact] {
        let entries = try repository.fetch(for: contact)
        return entries.map { entry in
            let verdict = entry.verdict ? "positively" : "negatively"
            let dateStr = dateFormatter.string(from: entry.date)
            let contactName = contact.givenName.isEmpty ? contact.name : contact.givenName
            return ContextFact(
                description: "You rated \"\(entry.activityDescription)\" with \(contactName) \(verdict) on \(dateStr)",
                source: .explicitFeedback
            )
        }
    }

    func userGoals() async throws -> [ContextFact] {
        // Feedback entries are contact-specific; no user-level goals to contribute.
        return []
    }
}
