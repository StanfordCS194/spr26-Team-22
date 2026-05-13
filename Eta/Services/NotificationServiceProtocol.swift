import Foundation

protocol NotificationServiceProtocol {
    /// Request permission to send notifications. No-op if already determined.
    func requestAuthorization() async throws

    /// Schedule a simulated acceptance notification for the given invitation.
    func sendInvitation(for invitation: Invitation) async throws

    /// Cancel a pending notification (e.g. if the invitation is cancelled).
    func cancelNotification(for invitationID: String)

    /// Schedule a notification after a hangout ends to prompt the user for feedback.
    func scheduleFeedbackNotification(hangoutID: UUID, friendName: String, activityName: String, at date: Date) async throws
}
