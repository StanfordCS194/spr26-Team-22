import Foundation

@Observable
class OnboardingViewModel {
    var userPreferences: UserPreferences = UserPreferences()

    var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding")
        }
    }

    init() {
        loadPreferences()
    }

    func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "userPreferences"),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            userPreferences = decoded
        }
    }

    func savePreferences() {
        if let encoded = try? JSONEncoder().encode(userPreferences) {
            UserDefaults.standard.set(encoded, forKey: "userPreferences")
        }
    }

    func completeOnboarding() {
        savePreferences()
        hasCompletedOnboarding = true
    }
}
