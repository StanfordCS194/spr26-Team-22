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
    func book(suggestion: Suggestion) -> UUID? {
        let hangout = ScheduledHangout(
            contact: suggestion.contact,
            activity: suggestion.activityDescription,
            selectedTime: suggestion.proposedTime
        )
        do {
            try hangoutRepository.add(hangout)
        } catch {
            return nil
        }

        NotificationCenter.default.post(name: .hangoutScheduled, object: nil)
        return hangout.id
    }

    func hasConflict(for interval: DateInterval) -> Bool {
        (try? hangoutRepository.hasOverlappingHangout(start: interval.start, end: interval.end)) ?? false
    }

    /// Opens Messages with a pre-filled invite text.
    /// Call this when the user taps "Send Invite" on the confirmation screen.
    func sendMessage(for suggestion: Suggestion) {
        provider.sendInvite(for: suggestion)
    }
}
