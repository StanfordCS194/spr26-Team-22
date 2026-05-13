import Foundation
import SwiftData

@MainActor
@Observable
final class InvitationManager {
    private let notificationService: any NotificationServiceProtocol
    private let modelContext: ModelContext
    private var analyticsService: AnalyticsService?
    var pendingFeedbackHangoutID: UUID?

    init(notificationService: any NotificationServiceProtocol, modelContext: ModelContext) {
        self.notificationService = notificationService
        self.modelContext = modelContext
    }

    func setAnalyticsService(_ service: AnalyticsService) {
        self.analyticsService = service
    }

    func fetchHangout(id: UUID) -> ScheduledHangout? {
        let descriptor = FetchDescriptor<ScheduledHangout>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func submitFeedback(hangoutID: UUID, friendRating: Int, activityRating: Int) throws {
        let hangout = fetchHangout(id: hangoutID)
        let feedback = HangoutFeedback(
            hangoutID: hangoutID,
            friendRating: friendRating,
            activityRating: activityRating
        )
        modelContext.insert(feedback)
        try modelContext.save()
        pendingFeedbackHangoutID = nil

        analyticsService?.logHangoutCompleted(
            contactID: hangout?.contact?.id,
            contactName: hangout?.contact?.name ?? "",
            hangoutID: hangoutID,
            friendRating: friendRating,
            activityRating: activityRating
        )
    }

    func dismissFeedback() {
        pendingFeedbackHangoutID = nil
    }

    /// Creates a pending invitation, requests notification permission if needed,
    /// and schedules a simulated acceptance notification.
    func acceptSuggestion(
        activityName: String,
        friendName: String,
        scheduledTime: Date,
        endDate: Date,
        hangoutID: UUID
    ) async throws -> Invitation {
        // Request permission inline on first use — no dedicated onboarding screen.
        try? await notificationService.requestAuthorization()

        let invitation = Invitation(
            activityName: activityName,
            friendName: friendName,
            scheduledTime: scheduledTime,
            hangoutID: hangoutID
        )
        modelContext.insert(invitation)
        try modelContext.save()

        try await notificationService.sendInvitation(for: invitation)
        await notificationService.scheduleHangoutReminders(
            hangoutID: hangoutID,
            activityName: activityName,
            friendName: friendName,
            startDate: scheduledTime,
            endDate: endDate
        )

        return invitation
    }

    /// Marks the invitation as confirmed or declined and updates the linked ScheduledHangout.
    /// Called by NotificationDelegate when the simulated (or real) response notification arrives.
    func handleInvitationResponse(invitationID: String, accepted: Bool) throws {
        let descriptor = FetchDescriptor<Invitation>(
            predicate: #Predicate { $0.id == invitationID }
        )
        guard let invitation = try modelContext.fetch(descriptor).first else { return }
        invitation.status = accepted ? .confirmed : .declined

        if let hangoutID = invitation.hangoutID {
            let hangoutDescriptor = FetchDescriptor<ScheduledHangout>(
                predicate: #Predicate { $0.id == hangoutID }
            )
            if let hangout = try modelContext.fetch(hangoutDescriptor).first {
                hangout.inviteeResponse = accepted ? .confirmed : .declined

                if accepted {
                    analyticsService?.logHangoutConfirmed(
                        contactID: hangout.contact?.id,
                        contactName: invitation.friendName,
                        hangoutID: hangout.id
                    )
                    Task {
                        try? await notificationService.scheduleFeedbackNotification(
                            hangoutID: hangout.id,
                            friendName: invitation.friendName,
                            activityName: invitation.activityName,
                            at: Date().addingTimeInterval(15) // TODO: revert to hangout.endDate after testing
                        )
                    }
                }
            }
        }

        try modelContext.save()
        NotificationCenter.default.post(name: .scheduledHangoutsDidChange, object: nil)
    }
}
