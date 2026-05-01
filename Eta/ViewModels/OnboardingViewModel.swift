import Foundation

@Observable
class OnboardingViewModel {
    private let preferencesService: PreferencesService
    var userPreferences: UserPreferences {
        get {
            preferencesService.preferences
        }
        set {
            preferencesService.updatePreferences(newValue)
        }
    }

    var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding")
        }
    }

    init(preferencesService: PreferencesService) {
        self.preferencesService = preferencesService
    }

    func completeOnboarding() {
        preferencesService.updatePreferences(userPreferences)
        hasCompletedOnboarding = true
    }
}
