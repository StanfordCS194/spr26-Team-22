import Foundation

/// Hardcoded pool of hangout activities for MVP.
/// Extend this enum to add more options; make it user-configurable in a future version.
enum Activity: String, CaseIterable, Identifiable {
    case walk         = "Go for a walk"
    case coffee       = "Grab coffee"
    case groceryRun   = "Do a grocery run"
    case lunch        = "Get lunch"
    case workout      = "Work out together"
    case coWork       = "Co-work"
    case drinks       = "Grab a drink"
    case videoCall    = "Video call"

    var id: String { rawValue }

    var pastTense: String {
        switch self {
        case .walk:       return "Went for a walk"
        case .coffee:     return "Grabbed coffee"
        case .groceryRun: return "Did a grocery run"
        case .lunch:      return "Got lunch"
        case .workout:    return "Worked out together"
        case .coWork:     return "Co-worked"
        case .drinks:     return "Grabbed a drink"
        case .videoCall:  return "Had a video call"
        }
    }

    /// True for activities that don't require being in the same place.
    var isRemote: Bool {
        switch self {
        case .videoCall: return true
        default: return false
        }
    }
}

// MARK: - ActivityRepresentable

extension Activity: ActivityRepresentable {
    /// Plain-English display string — forwards to rawValue.
    var description: String { rawValue }
}
