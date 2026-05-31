import Foundation

enum TagSubcategory: String, CaseIterable, Codable, Identifiable {
    // School
    case highSchool          = "High school"
    case college             = "College"
    case gradSchool          = "Grad school"

    // Work
    case currentColleague    = "Current colleague"
    case formerColleague     = "Former colleague"
    case professionalNetwork = "Professional network"
    case conferenceEvent     = "Conference / event"

    // Friends
    case childhoodFriend     = "Childhood friend"
    case roommate            = "Roommate"
    case friendGroup         = "Friend group"
    case clubHobbyGroup      = "Club / hobby group"
    case sportsTeam          = "Sports team"
    case travel              = "Travel"
    case friendOfFriend      = "Friend of a friend"
    case partnersFriend      = "Partner's friend"

    // Family
    case extendedFamily      = "Extended family"
    case familyFriend        = "Family friend"

    // Community
    case faithCommunity      = "Faith community"
    case volunteerOrg        = "Volunteer org"
    case neighbor            = "Neighbor"

    var id: String { rawValue }

    var parent: TagCategory {
        switch self {
        case .highSchool, .college, .gradSchool:
            return .school
        case .currentColleague, .formerColleague, .professionalNetwork, .conferenceEvent:
            return .work
        case .childhoodFriend, .roommate, .friendGroup, .clubHobbyGroup, .sportsTeam,
             .travel, .friendOfFriend, .partnersFriend:
            return .friends
        case .extendedFamily, .familyFriend:
            return .family
        case .faithCommunity, .volunteerOrg, .neighbor:
            return .community
        }
    }

    var supportsCustomLabel: Bool {
        switch self {
        case .clubHobbyGroup, .sportsTeam, .friendGroup, .faithCommunity,
             .volunteerOrg, .conferenceEvent, .travel:
            return true
        default:
            return false
        }
    }

    var customLabelPlaceholder: String {
        switch self {
        case .clubHobbyGroup:      return "e.g. Book club"
        case .sportsTeam:          return "e.g. Rec soccer league"
        case .friendGroup:         return "e.g. College squad"
        case .faithCommunity:      return "e.g. Grace Church"
        case .volunteerOrg:        return "e.g. Habitat for Humanity"
        case .conferenceEvent:     return "e.g. WWDC 2024"
        case .travel:              return "e.g. Japan trip 2023"
        default:                   return ""
        }
    }

    var defaultName: String { rawValue }
}
