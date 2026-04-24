import Foundation
import SwiftData

@Model
final class ScheduledHangout {
    var id: UUID
    var contactID: UUID
    var activity: String       // Activity.rawValue — stored as String; use resolvedActivity to get the enum
    var startDate: Date
    var endDate: Date
    var scheduledAt: Date

    init(
        id: UUID = UUID(),
        contactID: UUID,
        activity: Activity,
        proposedTime: DateInterval,
        scheduledAt: Date = .now
    ) {
        self.id = id
        self.contactID = contactID
        self.activity = activity.rawValue
        self.startDate = proposedTime.start
        self.endDate = proposedTime.end
        self.scheduledAt = scheduledAt
    }

    var proposedTime: DateInterval {
        DateInterval(start: startDate, end: endDate)
    }

    var resolvedActivity: Activity? {
        Activity(rawValue: activity)
    }
}
