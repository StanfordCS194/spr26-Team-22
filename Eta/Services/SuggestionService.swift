import Foundation

/// Generates a hangout suggestion by combining two signals:
/// 1. Opportunity — user-entered availability in the near-term window.
/// 2. Need       — a contact whose relationship health score is above the recency threshold
///
/// Both signals must be present. If either is absent, generateSuggestion() returns nil
/// and the For You inbox remains empty.
///
/// Contact selection (the "need" half) is handled inline here — health score ranking
/// is stable rules logic that does not need to be swapped independently.
/// Activity and reason selection is delegated to the injected ActivityStrategy.
///
/// SuggestionService depends on AvailabilityDataProvider concretely because user-entered
/// availability is a separate capability from historical relationship signals.
final class SuggestionService {
    private let availabilityProvider: AvailabilityDataProvider
    private let relationshipService: RelationshipService
    private let contextEngine: any ContextEngine
    private let activityStrategy: any ActivityStrategy
    private let fallbackStrategy: RulesActivityStrategy
    private let preferencesService: PreferencesService

    /// Contacts with a health score below this threshold are considered "recently seen"
    /// and do not qualify for a suggestion. 7.0 corresponds to roughly one week.
    private let minimumScoreThreshold: Double = 7

    /// Runtime-only log of activities suggested per contact this session.
    /// Cleared when the app is relaunched. Keyed by TrackedContact.id.
    private var suggestedActivities: [UUID: [String]] = [:]

    init(
        availabilityProvider: AvailabilityDataProvider,
        relationshipService: RelationshipService,
        contextEngine: any ContextEngine,
        activityStrategy: any ActivityStrategy,
        fallbackStrategy: RulesActivityStrategy,
        preferencesService: PreferencesService
    ) {
        self.availabilityProvider = availabilityProvider
        self.relationshipService = relationshipService
        self.contextEngine = contextEngine
        self.activityStrategy = activityStrategy
        self.fallbackStrategy = fallbackStrategy
        self.preferencesService = preferencesService
    }

    /// Returns a Suggestion when both a free slot and an overdue contact exist,
    /// nil otherwise. Uses saved availability, activity filtering,
    /// and relationship health thresholds.
    func generateSuggestion(
        diffContact: TrackedContact? = nil,
        diffTime: DateInterval? = nil,
        diffSuggestion: [String] = []
    ) async -> Suggestion? {
        // Signal 1: opportunity. Check first so an empty availability inbox stays quiet.
        let freeSlots: [DateInterval]
        do {
            let availableSlots = try await availabilityProvider.findAvailableSlots()
            freeSlots = preferredSlots(from: availableSlots, avoiding: diffTime)
        } catch {
            print(error.localizedDescription)
            return nil
        }
        guard !freeSlots.isEmpty else { return nil }

        // Signal 2: need. Rank contacts by health score.
        let healthScores = await relationshipService.computeHealth()
        guard let topHealth = topContact(from: healthScores, preferringDifferentFrom: diffContact) else {
            return nil
        }

        // Fetch context for the chosen contact. Failures produce empty context rather
        // than aborting — a suggestion without context is better than no suggestion.
        let baseContext: PromptContext
        do {
            baseContext = try await contextEngine.query(for: topHealth.contact)
        } catch {
            if isCancellation(error) {
                return nil
            }
            baseContext = .empty
        }
        var context = baseContext
        context.proposedTime = freeSlots.first
        // Use one explicit avoidance list for both strategy types:
        // session history prevents repeats during normal refreshes, while diffSuggestion
        // carries activities the user just asked to replace via the refresh button.
        context.previouslySuggestedActivities = orderedUnique(
            (suggestedActivities[topHealth.contact.id] ?? []) + diffSuggestion
        )

        // Delegate activity and reason selection to the strategy.
        // On LLM failure, fall back to the rules-based strategy so the inbox isn't left empty.
        var proposal: ActivityProposal
        do {
            if let proposalAttempt = try await activityStrategy.propose(for: topHealth, context: context) {
                proposal = proposalAttempt
            } else if let fallback = try await fallbackStrategy.propose(for: topHealth, context: context) {
                proposal = fallback
            } else {
                return nil
            }
        } catch {
            if isCancellation(error) {
                return nil
            }

            print(error.localizedDescription)
            guard let fallback = try? await fallbackStrategy.propose(for: topHealth, context: context) else {
                return nil
            }
            proposal = fallback
        }

        // Activity is the one refresh dimension that should definitively change.
        // If the primary strategy repeats anyway, retry through stricter fallbacks.
        if shouldRetryAvoidedProposal(proposal, context: context) {
            if let fallback = try? await fallbackStrategy.propose(for: topHealth, context: context) {
                proposal = fallback
            }
            if shouldRetryAvoidedProposal(proposal, context: context),
               let forcedProposal = forcedDifferentProposal(from: proposal, for: topHealth, context: context) {
                proposal = forcedProposal
            }
        }

        let suggestion = Suggestion(
            contact: topHealth.contact,
            activityDescription: proposal.activityDescription,
            reason: proposal.reason,
            proposedTimes: freeSlots,
            generatedAt: .now
        )
        suggestedActivities[topHealth.contact.id, default: []].append(proposal.activityDescription)
        return suggestion
    }

    // MARK: - Private

    /// Returns the contact to suggest.
    /// If a weekly priority is active (not suppressed, not waived), picks that contact
    /// as long as they have a non-zero score (no confirmed upcoming hangout).
    /// Otherwise falls back to the highest-scoring contact above the recency threshold.
    private func topContact(
        from healthScores: [RelationshipHealth],
        preferringDifferentFrom diffContact: TrackedContact?
    ) -> RelationshipHealth? {
        let eligible = healthScores.filter { health in
            health.contact.isActive
        }

        // Refresh should try another friend first, but a single eligible friend should
        // still get a new activity instead of dropping the inbox to empty.
        let preferredEligible = eligible.filter { health in
            guard let diffContact else { return true }
            return health.contact.id != diffContact.id
        }
        if let preferredContact = bestContact(from: preferredEligible) {
            return preferredContact
        }

        return bestContact(from: eligible)
    }

    private func bestContact(from healthScores: [RelationshipHealth]) -> RelationshipHealth? {
        if let priorityID = preferencesService.weeklyPriorityContactID(),
           !preferencesService.isWeeklyPrioritySuppressed(),
           !preferencesService.isWeeklyPriorityWaived(),
           let priorityHealth = healthScores.first(where: { $0.contact.id == priorityID }),
           priorityHealth.score > 0 {
            return priorityHealth
        }

        return healthScores
            .filter { $0.score >= minimumScoreThreshold }
            .max(by: { $0.score < $1.score })
    }

    private func preferredSlots(
        from slots: [DateInterval],
        avoiding diffTime: DateInterval?
    ) -> [DateInterval] {
        // Refresh should try another free slot first, but if there is only one viable
        // slot, keep it and let the activity change carry the refresh.
        let preferred = slots.filter { !isSameAvailabilityBlock($0, as: diffTime) }
        return preferred.isEmpty ? slots : preferred
    }

    private func isSameAvailabilityBlock(_ slot: DateInterval, as diffTime: DateInterval?) -> Bool {
        guard let diffTime else { return false }
        return abs(slot.start.timeIntervalSince(diffTime.start)) < 1
            && abs(slot.end.timeIntervalSince(diffTime.end)) < 1
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        return false
    }

    private func orderedUnique(_ activities: [String]) -> [String] {
        // Keep the first occurrence so avoidance order reflects what the user saw first.
        var seen: Set<String> = []
        return activities.filter { seen.insert($0).inserted }
    }

    private func shouldRetryAvoidedProposal(
        _ proposal: ActivityProposal,
        context: PromptContext
    ) -> Bool {
        // Some primary strategies degrade to a local random activity when the LLM is
        // unavailable; this keeps refresh-avoidance enforced in that no-key path too.
        context.previouslySuggestedActivities.contains(proposal.activityDescription)
    }

    private func forcedDifferentProposal(
        from proposal: ActivityProposal,
        for health: RelationshipHealth,
        context: PromptContext
    ) -> ActivityProposal? {
        // Last resort for refresh: pick the first enum activity that was not just shown.
        let avoided = Set(context.previouslySuggestedActivities)
        guard let activity = Activity.allCases.first(where: {
            $0.isRemote == health.contact.isRemote && !avoided.contains($0.description)
        }) else {
            return nil
        }
        return ActivityProposal(
            activityDescription: activity.description,
            reason: proposal.reason
        )
    }
}
