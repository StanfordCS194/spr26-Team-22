import Foundation

/// Stores the user's preferred hangout length for future suggestions.
final class ActivityDurationSettings {
    /// Shortest supported hangout duration.
    static let minimumMinutes = 15
    /// Longest supported hangout duration.
    static let maximumMinutes = 360
    /// Granularity for duration edits.
    static let stepMinutes = 15

    private let defaults: UserDefaults
    private let key = "activity.duration.minutes"

    /// Creates a settings store backed by the supplied defaults container.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Preferred hangout length in minutes, normalized to a 15-minute step.
    var minutes: Int {
        get {
            let stored = defaults.integer(forKey: key)
            return normalized(stored == 0 ? 60 : stored)
        }
        set {
            defaults.set(normalized(newValue), forKey: key)
        }
    }

    /// Preferred hangout length as a `TimeInterval`, suitable for `DateInterval` construction.
    var duration: TimeInterval {
        TimeInterval(minutes * 60)
    }

    /// Clamps a raw minute value into the supported range and rounds to the nearest step.
    private func normalized(_ value: Int) -> Int {
        let clamped = min(max(value, Self.minimumMinutes), Self.maximumMinutes)
        let rounded = ((clamped + Self.stepMinutes / 2) / Self.stepMinutes) * Self.stepMinutes
        return min(max(rounded, Self.minimumMinutes), Self.maximumMinutes)
    }
}
