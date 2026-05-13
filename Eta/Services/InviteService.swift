import Foundation

final class InviteService {
    private let provider: any InviteProvider
    private let hangoutRepository: ScheduledHangoutRepository

    init(
        provider: any InviteProvider,
        hangoutRepository: ScheduledHangoutRepository
    ) {
        self.provider = provider
        self.hangoutRepository = hangoutRepository
    }

    /// Persists the scheduled hangout using the first proposed availability option.
    /// Returns the hangout's UUID so the caller can link the resulting Invitation to it.
    @discardableResult
    func book(suggestion: Suggestion) -> UUID {
        let hangout = ScheduledHangout(
            contact: suggestion.contact,
            activity: suggestion.activityDescription,
            selectedTime: suggestion.proposedTime
        )
        try? hangoutRepository.add(hangout)
        return hangout.id
    }

    /// Opens Messages with a pre-filled invite text.
    /// Call this when the user taps "Send Invite" on the confirmation screen.
    func sendMessage(for suggestion: Suggestion) {
        provider.sendInvite(for: suggestion)
    }
}
