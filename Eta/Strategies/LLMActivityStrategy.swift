import Foundation

/// Selects a hangout activity by prompting a language model with context about
/// the user's relationship with the contact.
///
/// ActivityType = String (free-form, LLM-generated). The model is asked to respond
/// with only a short imperative phrase (e.g. "Grab coffee", "Go rock climbing")
/// which is used directly as the activityDescription in ActivityProposal.
///
/// Swap the LLMRunner conformer in EtaApp.swift to change the underlying model
/// (StubLLMRunner → SpeziLLMRunner → remote API) without touching this class.
final class LLMActivityStrategy: ActivityStrategy {
    typealias ActivityType = String

    private let runner: any LLMRunner

    init(runner: any LLMRunner) {
        self.runner = runner
    }

    func propose(
        for health: RelationshipHealth,
        context: PromptContext
    ) async throws -> ActivityProposal? {
        if health.contact.isRemote {
            return ActivityProposal(
                activityDescription: Activity.videoCall.description,
                reason: reason(for: health)
            )
        }

        let systemPrompt = """
        You are a helpful assistant that suggests activities for friends to do together. \
        Suggest a single short activity phrase (2–5 words, imperative form, e.g. "Grab coffee", "Go for a walk"). \
        Reply with ONLY the activity phrase — no punctuation, no explanation, nothing else.
        """

        let contactName = health.contact.givenName.isEmpty
            ? health.contact.name
            : health.contact.givenName

        let allFacts = context.relationshipFacts + context.userGoals
        let factLines = allFacts.isEmpty
            ? "No context available."
            : allFacts.map { "- \($0.description)" }.joined(separator: "\n")

        let userPrompt = """
        Context about the user's relationship with \(contactName):
        \(factLines)

        Suggest one new activity for them to do together not previously seen.
        """

        let raw: String
        do {
            raw = try await runner.generate(systemPrompt: systemPrompt, userPrompt: userPrompt)
        } catch {
            if isCancellation(error) {
                throw error
            }

            if isRateLimit(error) {
                return fallbackProposal(for: health, error: error)
            }

            print("[LLMActivityStrategy] runner error: \(error.localizedDescription)")

            // Give the LLM a little time before degrading
            do {
                try await Task.sleep(nanoseconds: 2_500_000_000)

                raw = try await runner.generate(
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt
                )
            } catch {
                if isCancellation(error) {
                    throw error
                }

                return fallbackProposal(for: health, error: error)
            }
        }

        let activityDescription = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !activityDescription.isEmpty else { return nil }

        return ActivityProposal(
            activityDescription: activityDescription,
            reason: reason(for: health)
        )
    }

    // MARK: - Private

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        return false
    }

    private func isRateLimit(_ error: Error) -> Bool {
        error.localizedDescription.contains("HTTP 429")
    }

    private func fallbackProposal(for health: RelationshipHealth, error: Error) -> ActivityProposal {
        // Fallback to a random Activity on runner errors that should not keep retrying.
        print("[LLMActivityStrategy] runner error — falling back to random activity: \(error.localizedDescription)")
        let description = Activity.allCases.randomElement()?.description ?? Activity.coffee.description
        return ActivityProposal(activityDescription: description, reason: reason(for: health))
    }

    private func reason(for health: RelationshipHealth) -> String {
        guard let days = health.daysSinceLastHangout else {
            return "You two haven't hung out yet"
        }
        switch days {
        case 7..<14:
            return "You haven't hung out in over a week"
        case 14..<30:
            return "It's been \(days) days since your last hangout"
        default:
            return "You haven't hung out in over a month"
        }
    }
}
