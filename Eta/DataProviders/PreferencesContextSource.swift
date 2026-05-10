import Foundation

/// Derives user-level activity preference facts from UserDefaults.
///
/// Activity preferences are set during onboarding (not yet implemented) and stored
/// as an array of strings under the key "preferredActivities". Returns an empty
/// array until onboarding writes values.
///
/// No contact-specific facts are produced by this source — preferences apply globally.
final class PreferencesContextSource: ContextSource {
    private let preferencesService: PreferencesService
    
    init (preferencesService: PreferencesService) {
        self.preferencesService = preferencesService
    }

    func facts(for contact: TrackedContact) async throws -> [ContextFact] {
        // Preferences are user-level, not contact-specific.
        return []
    }

    func userGoals() async throws -> [ContextFact] {
        let preferred = preferencesService.preferences.preferredActivities
        
        guard !preferred.isEmpty else {
            return []
        }

        let list = preferred.joined(separator: ", ")
        return [ContextFact(
            description: "The user enjoys these types of activities: \(list)",
            source: .onboardingPreferences
        )]
    }
}
