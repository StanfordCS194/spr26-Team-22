import Foundation

/// Derives relationship facts from the user's post-hangout feedback history.
///
/// Feedback covers two dimensions: company quality (1 = Meh, 2 = Good, 3 = Great)
/// and activity repeatability (0 = wouldn't repeat, 1 = would repeat).
///
/// Facts produced for a specific contact:
///   - Which activities the user enjoyed or skipped with that person
///   - Overall company sentiment when there are enough entries to aggregate
///   - A plain-English log of the three most recent feedback entries
///
/// User-goal facts surface activities the user has rated positively across all contacts,
/// giving the LLM a baseline of what the user tends to enjoy independent of friendship.
final class HangoutFeedbackContextSource: ContextSource {
    private let feedbackRepository: HangoutFeedbackRepository
    private let hangoutRepository: ScheduledHangoutRepository

    init(
        feedbackRepository: HangoutFeedbackRepository,
        hangoutRepository: ScheduledHangoutRepository
    ) {
        self.feedbackRepository = feedbackRepository
        self.hangoutRepository = hangoutRepository
    }

    // MARK: - ContextSource

    func facts(for contact: TrackedContact) async throws -> [ContextFact] {
        let allFeedback = try feedbackRepository.fetchAll()
        guard !allFeedback.isEmpty else { return [] }

        let allHangouts = try hangoutRepository.fetchAll()
        let hangoutByID: [UUID: ScheduledHangout] = Dictionary(
            uniqueKeysWithValues: allHangouts.map { ($0.id, $0) }
        )

        // Filter to feedback entries whose hangout belongs to this contact.
        let contactFeedback = allFeedback.filter { entry in
            hangoutByID[entry.hangoutID]?.contact?.id == contact.id
        }

        guard !contactFeedback.isEmpty else { return [] }

        var facts: [ContextFact] = []

        // --- Activity preference summary ---
        let likedActivities = contactFeedback
            .filter { $0.activityRating == 1 }
            .compactMap { hangoutByID[$0.hangoutID]?.activity }
        let dislikedActivities = contactFeedback
            .filter { $0.activityRating == 0 }
            .compactMap { hangoutByID[$0.hangoutID]?.activity }

        let uniqueLiked = ordered(Set(likedActivities))
        let uniqueDisliked = ordered(Set(dislikedActivities))

        if !uniqueLiked.isEmpty {
            facts.append(ContextFact(
                description: "Activities you've enjoyed with \(contact.givenName): \(uniqueLiked.joined(separator: ", "))",
                source: .explicitFeedback
            ))
        }

        if !uniqueDisliked.isEmpty {
            facts.append(ContextFact(
                description: "Activities you'd rather not repeat with \(contact.givenName): \(uniqueDisliked.joined(separator: ", "))",
                source: .explicitFeedback
            ))
        }

        // --- Aggregate company sentiment (requires ≥ 2 entries to be meaningful) ---
        if contactFeedback.count >= 2 {
            let average = Double(contactFeedback.map(\.friendRating).reduce(0, +)) / Double(contactFeedback.count)
            let sentiment: String
            switch average {
            case ..<1.5: sentiment = "generally okay but not memorable"
            case 1.5..<2.5: sentiment = "usually good"
            default: sentiment = "consistently great"
            }
            facts.append(ContextFact(
                description: "Across \(contactFeedback.count) hangout(s), you've found \(contact.givenName)'s company \(sentiment)",
                source: .explicitFeedback
            ))
        }

        // --- Recent entry log (up to 3, newest first) ---
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        for entry in contactFeedback.prefix(3) {
            guard let hangout = hangoutByID[entry.hangoutID] else { continue }
            let companyLabel = friendRatingLabel(entry.friendRating)
            let activityLabel = entry.activityRating == 1 ? "would repeat" : "wouldn't repeat"
            let dateString = dateFormatter.string(from: entry.submittedAt)
            facts.append(ContextFact(
                description: "On \(dateString), you rated \(hangout.activity) with \(contact.givenName) as \(companyLabel) company (\(activityLabel))",
                source: .explicitFeedback
            ))
        }

        return facts
    }

    func userGoals() async throws -> [ContextFact] {
        let allFeedback = try feedbackRepository.fetchAll()
        guard !allFeedback.isEmpty else { return [] }

        let allHangouts = try hangoutRepository.fetchAll()
        let hangoutByID: [UUID: ScheduledHangout] = Dictionary(
            uniqueKeysWithValues: allHangouts.map { ($0.id, $0) }
        )

        // Collect activities the user has rated positively (thumbs up) across all hangouts.
        let globallyLiked = allFeedback
            .filter { $0.activityRating == 1 }
            .compactMap { hangoutByID[$0.hangoutID]?.activity }

        let uniqueGloballyLiked = ordered(Set(globallyLiked))
        guard !uniqueGloballyLiked.isEmpty else { return [] }

        return [ContextFact(
            description: "Based on past feedback, you tend to enjoy: \(uniqueGloballyLiked.joined(separator: ", "))",
            source: .explicitFeedback
        )]
    }

    // MARK: - Helpers

    private func friendRatingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return "okay"
        case 2: return "good"
        case 3: return "great"
        default: return "rated \(rating)/3"
        }
    }

    /// Returns a stable ordering for a set of activity strings to keep facts deterministic.
    private func ordered(_ set: Set<String>) -> [String] {
        set.sorted()
    }
}
