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

    private func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: "userPreferences")
        }
    }
}
