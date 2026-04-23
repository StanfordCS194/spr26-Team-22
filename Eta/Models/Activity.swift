import Foundation

/// Hardcoded pool of hangout activities for MVP.
/// Extend this enum to add more options; make it user-configurable in a future version.
enum Activity: String, CaseIterable, Identifiable {
    case walk         = "Go for a walk"
    case coffee       = "Grab coffee"
    case groceryRun   = "Do a grocery run"
    case lunch        = "Get lunch"
    case workout      = "Work out together"
    case studySession = "Study together"

    var id: String { rawValue }
}
