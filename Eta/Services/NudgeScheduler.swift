import Foundation

/// Prepares a Suggestion from nudge context (contact + activity) by finding the next free slot.
/// The caller passes the result to SuggestionViewModel.scheduleFromNudge(_:) to drive the
/// standard scheduling flow (accepted → invitationSent) in the suggestions tab.
final class NudgeScheduler {
    private let availabilityProvider: AvailabilityDataProvider

    init(availabilityProvider: AvailabilityDataProvider) {
        self.availabilityProvider = availabilityProvider
    }

    /// Returns nil if no free slot is found in the look-ahead window.
    func buildSuggestion(contact: TrackedContact, activityRawValue: String) async -> Suggestion? {
        guard let slot = try? await availabilityProvider.findAvailableSlots(maximumCount: 1).first else { return nil }
        return Suggestion(
            contact: contact,
            activityDescription: activityRawValue,
            reason: "Nudge",
            proposedTimes: [slot],
            generatedAt: .now
        )
    }
}
