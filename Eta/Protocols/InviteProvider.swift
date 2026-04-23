import Foundation

/// Delivers a hangout invite for the given suggestion.
///
/// Today: iMessageInviteProvider (iMessage URL scheme / pre-filled draft).
/// Tomorrow: iMessage extension with collaborative planning and calendar sync.
/// Swap implementations in EtaApp.swift without touching InviteService.
protocol InviteProvider {
    func sendInvite(for suggestion: Suggestion)
}
