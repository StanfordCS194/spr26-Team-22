import Foundation

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

    private func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: "userPreferences")
        }
    }
}
