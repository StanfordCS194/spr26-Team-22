import Foundation
import SwiftData

@Model
final class HangoutFeedback {
    var id: UUID
    var hangoutID: UUID
    var friendRating: Int
    var activityRating: Int
    var submittedAt: Date

    init(
        id: UUID = UUID(),
        hangoutID: UUID,
        friendRating: Int,
        activityRating: Int,
        submittedAt: Date = Date()
    ) {
        self.id = id
        self.hangoutID = hangoutID
        self.friendRating = friendRating
        self.activityRating = activityRating
        self.submittedAt = submittedAt
    }
}
