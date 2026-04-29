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
    /// Call this when the user confirms ("Yes, let's do it!").
    func book(suggestion: Suggestion) {
        let hangout = ScheduledHangout(
            contact: suggestion.contact,
            activity: suggestion.activity,
            proposedTime: suggestion.proposedTime
        )
        try? hangoutRepository.add(hangout)
        calendarDataProvider.createEvent(for: suggestion)
    }

    /// Opens Messages with a pre-filled invite text.
    /// Call this when the user taps "Send Invite" on the confirmation screen.
    func sendMessage(for suggestion: Suggestion) {
        provider.sendInvite(for: suggestion)
    }
}
