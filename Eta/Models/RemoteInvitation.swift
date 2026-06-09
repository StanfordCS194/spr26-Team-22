import Foundation

struct RemoteInvitation: Codable, Identifiable {
    let id: String
    let fromDevice: String
    let fromIdentifier: String
    let toIdentifier: String
    let friendName: String
    let activity: String
    let startTime: Date
    let endTime: Date
    let status: String
    let previousInvitationID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fromDevice             = "from_device"
        case fromIdentifier         = "from_identifier"
        case toIdentifier           = "to_identifier"
        case friendName             = "friend_name"
        case activity
        case startTime              = "start_time"
        case endTime                = "end_time"
        case status
        case previousInvitationID   = "previous_invitation_id"
    }
}
