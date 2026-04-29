import SwiftData
import Foundation

enum InvitationStatus: String, Codable {
    case pending    // invitation sent, waiting for response
    case confirmed  // invitee accepted
}

@Model
final class Invitation {
    var id: String
    var activityName: String
    var friendName: String
    var scheduledTime: Date
    var createdAt: Date
    var invitationStatusRaw: String

    var status: InvitationStatus {
        get { InvitationStatus(rawValue: invitationStatusRaw) ?? .pending }
        set { invitationStatusRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        activityName: String,
        friendName: String,
        scheduledTime: Date,
        createdAt: Date = Date(),
        status: InvitationStatus = .pending
    ) {
        self.id = id
        self.activityName = activityName
        self.friendName = friendName
        self.scheduledTime = scheduledTime
        self.createdAt = createdAt
        self.invitationStatusRaw = status.rawValue
    }
}
