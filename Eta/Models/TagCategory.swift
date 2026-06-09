import Foundation
import SwiftUI

enum TagCategory: String, CaseIterable, Codable, Identifiable {
    case school     = "School"
    case work       = "Work"
    case friends    = "Friends"
    case family     = "Family"
    case community  = "Community"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .school:    return .yellow
        case .work:      return .blue
        case .friends:   return .orange
        case .family:    return .green
        case .community: return .teal
        }
    }

    var icon: String {
        switch self {
        case .school:    return "graduationcap"
        case .work:      return "briefcase"
        case .friends:   return "person.2"
        case .family:    return "house"
        case .community: return "building.2"
        }
    }
}
