import Foundation

@Observable
class OnboardingViewModel {
    private let preferencesService: PreferencesService
    private let onComplete: () -> Void

    var userPreferences: UserPreferences {
        get { preferencesService.preferences }
        set { preferencesService.updatePreferences(newValue) }
    }

    var hasCompletedOnboarding: Bool

    init(preferencesService: PreferencesService, onComplete: @escaping () -> Void = {}) {
        self.preferencesService = preferencesService
        self.onComplete = onComplete
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func completeOnboarding() {
        preferencesService.updatePreferences(userPreferences)
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete()
    }
}
