import Foundation
import SwiftData

@Model
final class ActivityPhoto {
    var id: UUID
    var activityRawValue: String
    var hangoutID: UUID?
    var imageData: Data
    var capturedAt: Date

    init(activity: Activity, hangoutID: UUID? = nil, imageData: Data) {
        self.id = UUID()
        self.activityRawValue = activity.rawValue
        self.hangoutID = hangoutID
        self.imageData = imageData
        self.capturedAt = .now
    }

    var activity: Activity? {
        Activity(rawValue: activityRawValue)
    }
}
