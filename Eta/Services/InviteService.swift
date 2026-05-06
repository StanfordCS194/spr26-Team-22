import Foundation

final class InviteService {
    private let provider: any InviteProvider
    private let hangoutRepository: ScheduledHangoutRepository
    private let calendarDataProvider: CalendarDataProvider

    init(
        provider: any InviteProvider,
        hangoutRepository: ScheduledHangoutRepository,
        calendarDataProvider: CalendarDataProvider
    ) {
        self.provider = provider
        self.hangoutRepository = hangoutRepository
        self.calendarDataProvider = calendarDataProvider
    }

    /// Persists the scheduled hangout and creates a calendar event on the user's calendar.
    /// Returns the hangout's UUID so the caller can link the resulting Invitation to it.
    @discardableResult
    func book(suggestion: Suggestion) -> UUID {
        let hangout = ScheduledHangout(
            contact: suggestion.contact,
            activity: suggestion.activityDescription,
            proposedTime: suggestion.proposedTime
        )
        try? hangoutRepository.add(hangout)
        calendarDataProvider.createEvent(for: suggestion)
        return hangout.id
    }

    /// Opens Messages with a pre-filled invite text.
    /// Call this when the user taps "Send Invite" on the confirmation screen.
    func sendMessage(for suggestion: Suggestion) {
        provider.sendInvite(for: suggestion)
    }
}
