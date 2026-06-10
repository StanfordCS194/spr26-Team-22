import Foundation

/// Delivers a hangout invite for the given suggestion.
///
/// Today: iMessageInviteProvider (iMessage URL scheme / pre-filled draft).
/// Tomorrow: iMessage extension with collaborative planning.
/// Swap implementations in EtaApp.swift without touching InviteService.
protocol InviteProvider {
    /// Opens the iMessage compose sheet with a pre-filled invite.
    /// `invitationID` is the Supabase record ID so the message body can embed the web RSVP link.
    func sendInvite(for suggestion: Suggestion, invitationID: String)
}
