import Foundation

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// Manages user preferences — loads from UserDefaults, provides access to all services.
final class PreferencesService {
    private(set) var preferences: UserPreferences

    init() {
        if let data = UserDefaults.standard.data(forKey: "userPreferences"),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            self.preferences = decoded
        } else {
            self.preferences = UserPreferences()
        }
    }

    func updatePreferences(_ updatedPreferences: UserPreferences) {
        self.preferences = updatedPreferences
        savePreferences()
    }

    func updateCheckInTemplate(_ template: String) {
        preferences.checkInTemplate = template
        preferences.hasSetCheckInTemplate = true
        savePreferences()
    }

    func markCheckInTemplateSet() {
        preferences.hasSetCheckInTemplate = true
        savePreferences()
    }

    func updateUserCity(_ city: String?) {
        preferences.userCity = city?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        savePreferences()
    }

    func updateNudgeFrequency(_ days: Int) {
        preferences.nudgeFrequencyDays = min(max(days, 1), 7)
        savePreferences()
    }

    func updateUserCoordinates(_ latitude: Double, _ longitude: Double) {
        preferences.userLatitude = latitude
        preferences.userLongitude = longitude
        savePreferences()
    }

    // MARK: - Weekly priority (week-keyed UserDefaults, resets automatically each new week)

    private var weekKey: String {
        let ts = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start.timeIntervalSince1970 ?? 0
        return "wcp_\(Int(ts))"
    }

    func weeklyPriorityContactID() -> UUID? {
        guard let str = UserDefaults.standard.string(forKey: weekKey + "_id") else { return nil }
        return UUID(uuidString: str)
    }

    func setWeeklyPriority(_ contactID: UUID?) {
        if let id = contactID {
            UserDefaults.standard.set(id.uuidString, forKey: weekKey + "_id")
        } else {
            UserDefaults.standard.removeObject(forKey: weekKey + "_id")
        }
        // Reset dismiss state whenever the priority contact changes.
        UserDefaults.standard.removeObject(forKey: weekKey + "_dismissCount")
        UserDefaults.standard.removeObject(forKey: weekKey + "_suppressedUntil")
    }

    func weeklyDismissCount() -> Int {
        UserDefaults.standard.integer(forKey: weekKey + "_dismissCount")
    }

    /// Increments the dismiss count and applies suppression/waiver thresholds.
    /// 2nd dismiss → 24-hour suppression. 3rd dismiss → priority waived for rest of week.
    func incrementWeeklyDismissCount() {
        let newCount = weeklyDismissCount() + 1
        UserDefaults.standard.set(newCount, forKey: weekKey + "_dismissCount")
        if newCount == 2 {
            let until = Date().addingTimeInterval(24 * 60 * 60).timeIntervalSince1970
            UserDefaults.standard.set(until, forKey: weekKey + "_suppressedUntil")
        }
    }

    func isWeeklyPrioritySuppressed() -> Bool {
        let until = UserDefaults.standard.double(forKey: weekKey + "_suppressedUntil")
        guard until > 0 else { return false }
        return Date() < Date(timeIntervalSince1970: until)
    }

    func isWeeklyPriorityWaived() -> Bool {
        weeklyDismissCount() >= 3
    }

    func hasCompletedCheckInThisWeek() -> Bool {
        UserDefaults.standard.bool(forKey: weekKey + "_done")
    }

    func markCheckInCompleted() {
        UserDefaults.standard.set(true, forKey: weekKey + "_done")
    }

    /// Clears weekly priority and dismiss state. Does NOT reset day/time preferences.
    func clearWeeklyData() {
        UserDefaults.standard.removeObject(forKey: weekKey + "_id")
        UserDefaults.standard.removeObject(forKey: weekKey + "_dismissCount")
        UserDefaults.standard.removeObject(forKey: weekKey + "_suppressedUntil")
        UserDefaults.standard.removeObject(forKey: weekKey + "_done")
    }

    private func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: "userPreferences")
        }
    }
}
