import Foundation
import SwiftData

/// The raw response stored on the model. Status is derived from this — never stored directly.
enum InviteeResponse: String, Codable {
    case pending    // awaiting reply
    case confirmed  // invitee accepted
    case declined   // invitee declined
}

@Model
final class ScheduledHangout {
    var id: UUID
    var invitationID: String?
    var contact: TrackedContact?
    /// Display fallback when `contact` is nil — e.g. when accepted via iMessage or web RSVP
    /// and the sender isn't in the receiver's TrackedContacts.
    var contactName: String?
    var activity: String       // Activity.rawValue — stored as String; use resolvedActivity to get the enum

    var startDate: Date
    var endDate: Date

    var scheduledAt: Date
    var inviteeResponse: InviteeResponse

    init(
        id: UUID = UUID(),
        contact: TrackedContact,
        activity: String,
        selectedTime: DateInterval,
        scheduledAt: Date = .now
    ) {
        self.id = id
        self.contact = contact
        self.contactName = nil
        self.activity = activity
        self.startDate = selectedTime.start
        self.endDate = selectedTime.end
        self.scheduledAt = scheduledAt
        self.inviteeResponse = .pending
    }

    /// Creates a confirmed hangout from an iMessage or web RSVP where the sender
    /// may not be a TrackedContact on this device.
    init(
        id: UUID = UUID(),
        contactName: String?,
        activity: String,
        selectedTime: DateInterval,
        scheduledAt: Date = .now
    ) {
        self.id = id
        self.contact = nil
        self.contactName = contactName
        self.activity = activity
        self.startDate = selectedTime.start
        self.endDate = selectedTime.end
        self.scheduledAt = scheduledAt
        self.inviteeResponse = .pending
    }
    //Selected Event Time
    var selectedTime: DateInterval {
        DateInterval(start: startDate, end: endDate)
    }

    /// Attempts to resolve the stored activity string back to a structured Activity case.
    /// Returns nil for LLM-generated activities that don't match any known case.
    var resolvedActivity: Activity? {
            Activity(rawValue: activity)
        }

    /// Derived from inviteeResponse — never stored or set directly.
    /// Update inviteeResponse to change status.
    var status: HangoutStatus {
        switch inviteeResponse {
        case .pending:   return .pending
        case .confirmed: return .confirmed
        case .declined:  return .canceled
        }
    }
}
