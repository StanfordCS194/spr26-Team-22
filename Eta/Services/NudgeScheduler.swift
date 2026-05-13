import Foundation

/// Prepares a Suggestion from nudge context (contact + activity) by finding the next free slot.
/// The caller passes the result to SuggestionViewModel.scheduleFromNudge(_:) to drive the
/// standard scheduling flow (accepted → invitationSent) in the suggestions tab.
final class NudgeScheduler {
    private let availabilityDataProvider: AvailabilityDataProvider

    init(availabilityDataProvider: AvailabilityDataProvider) {
        self.availabilityDataProvider = availabilityDataProvider
    }

    /// Returns nil if no free slot is found in the look-ahead window.
    func buildSuggestion(contact: TrackedContact, activityRawValue: String) async -> Suggestion? {
        guard let slots = try? await availabilityDataProvider.findAvailableSlots() else { return nil }
        return Suggestion(
            contact: contact,
            activityDescription: activityRawValue,
            reason: "Nudge",
            proposedTimes: slots,
            generatedAt: .now
        )
    }
}
