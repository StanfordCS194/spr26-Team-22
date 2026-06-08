import Foundation
import SwiftData

@Model final class PendingReceivedInvitation {
    var id: String
    var fromDevice: String
    var fromIdentifier: String
    var friendName: String
    var senderName: String = ""
    var isEdit: Bool = false
    var activity: String
    var startTime: Date
    var endTime: Date
    var receivedAt: Date

    init(remote: RemoteInvitation, senderName: String, isEdit: Bool = false) {
        self.id = remote.id
        self.fromDevice = remote.fromDevice
        self.fromIdentifier = remote.fromIdentifier
        self.friendName = remote.friendName
        self.senderName = senderName
        self.isEdit = isEdit
        self.activity = remote.activity
        self.startTime = remote.startTime
        self.endTime = remote.endTime
        self.receivedAt = .now
    }

    var asRemoteInvitation: RemoteInvitation {
        RemoteInvitation(
            id: id,
            fromDevice: fromDevice,
            fromIdentifier: fromIdentifier,
            toIdentifier: "",
            friendName: friendName,
            activity: activity,
            startTime: startTime,
            endTime: endTime,
            status: "pending",
            previousInvitationID: nil
        )
    }
}
