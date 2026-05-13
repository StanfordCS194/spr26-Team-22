import Foundation


@MainActor
protocol NotificationServiceProtocol {
    /// Request permission to send notifications. No-op if already determined.
    func requestAuthorization() async throws

    /// Schedule a simulated acceptance notification for the given invitation.
    func sendInvitation(for invitation: Invitation) async throws

    /// Cancel a pending notification (e.g. if the invitation is cancelled).
    func cancelNotification(for invitationID: String)

    /// Schedule a notification after a hangout ends to prompt the user for feedback.
    func scheduleFeedbackNotification(hangoutID: UUID, friendName: String, activityName: String, at date: Date) async throws
    /// Schedule a heads-up (30 min before start) and photo-capture (at end) notification pair.
    func scheduleHangoutReminders(hangoutID: UUID, activityName: String, friendName: String, startDate: Date, endDate: Date) async

    /// Cancel both reminder notifications for a hangout.
    func cancelHangoutReminders(for hangoutID: UUID)

    /// Schedule a local notification for an incoming remote invitation with Accept/Decline actions.
    func scheduleReceivedInvitationNotification(remote: RemoteInvitation) async throws
}
