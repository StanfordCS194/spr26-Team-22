import Foundation

@Observable
class OnboardingViewModel {
    private let preferencesService: PreferencesService

    var userPreferences: UserPreferences {
        get { preferencesService.preferences }
        set { preferencesService.updatePreferences(newValue) }
    }

    // Stored property — @Observable can now track this
    var hasCompletedOnboarding: Bool

    init(preferencesService: PreferencesService) {
        self.preferencesService = preferencesService
        // Seed from UserDefaults on init
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func completeOnboarding() {
        preferencesService.updatePreferences(userPreferences)
        hasCompletedOnboarding = true
        // Persist for next launch
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}git