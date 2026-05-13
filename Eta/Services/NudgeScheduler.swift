import Foundation

/// Prepares a Suggestion from nudge context (contact + activity) by finding the next free slot.
/// The caller passes the result to SuggestionViewModel.scheduleFromNudge(_:) to drive the
/// standard scheduling flow (accepted → invitationSent) in the suggestions tab.
final class NudgeScheduler {
    private let calendarDataProvider: CalendarDataProvider

    init(calendarDataProvider: CalendarDataProvider) {
        self.calendarDataProvider = calendarDataProvider
    }

    /// Returns nil if no free slot is found in the look-ahead window.
    func buildSuggestion(contact: TrackedContact, activityRawValue: String) -> Suggestion? {
        guard let slot = calendarDataProvider.findFreeSlot() else { return nil }
        return Suggestion(
            contact: contact,
            activityDescription: activityRawValue,
            reason: "Nudge",
            proposedTime: slot,
            generatedAt: .now
        )
    }
}
