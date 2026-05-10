import Foundation

@Observable
class OnboardingViewModel {
    private let preferencesService: PreferencesService

    var userPreferences: UserPreferences {
        get { preferencesService.preferences }
        set { preferencesService.updatePreferences(newValue) }
    }

    var hasCompletedOnboarding: Bool

    init(preferencesService: PreferencesService) {
        self.preferencesService = preferencesService
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func completeOnboarding() {
        preferencesService.updatePreferences(userPreferences)
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}
