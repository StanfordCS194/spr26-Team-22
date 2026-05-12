import Foundation
import SwiftData

@MainActor
@Observable
final class InvitationManager {
    private let notificationService: any NotificationServiceProtocol
    private let modelContext: ModelContext

    init(notificationService: any NotificationServiceProtocol, modelContext: ModelContext) {
        self.notificationService = notificationService
        self.modelContext = modelContext
    }

    /// Creates a pending invitation, requests notification permission if needed,
    /// and schedules a simulated acceptance notification.
    func acceptSuggestion(
        activityName: String,
        friendName: String,
        scheduledTime: Date,
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
            }
        }

        try modelContext.save()
    }
}
