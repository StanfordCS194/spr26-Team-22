protocol NotificationServiceProtocol {
    /// Request permission to send notifications. No-op if already determined.
    func requestAuthorization() async throws

    /// Schedule a simulated acceptance notification for the given invitation.
    func sendInvitation(for invitation: Invitation) async throws

    /// Cancel a pending notification (e.g. if the invitation is cancelled).
    func cancelNotification(for invitationID: String)

    /// Schedule a heads-up (30 min before start) and photo-capture (at end) notification pair.
    func scheduleHangoutReminders(hangoutID: UUID, activityName: String, friendName: String, startDate: Date, endDate: Date) async

    /// Cancel both reminder notifications for a hangout.
    func cancelHangoutReminders(for hangoutID: UUID)
}
