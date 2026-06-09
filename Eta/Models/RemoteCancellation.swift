import Foundation

struct RemoteCancellation: Codable, Identifiable {
    let id: String
    let fromIdentifier: String
    let toIdentifier: String
    let friendName: String
    let activity: String

    enum CodingKeys: String, CodingKey {
        case id
        case fromIdentifier = "from_identifier"
        case toIdentifier   = "to_identifier"
        case friendName     = "friend_name"
        case activity
    }
}
