//
//  UserPreferencesService.swift
//  Eta
//

import Foundation
import Combine

final class UserPreferencesService: ObservableObject {

    // MARK: - Keys
    private enum Keys {
        static let activities       = "eta.prefs.activities"
        static let defaultFrequency = "eta.prefs.defaultFrequency"
        static let onboardingDone   = "eta.onboarding.complete"
    }

    // MARK: - Published
    @Published private(set) var favoriteActivities: Set<ActivityType> = []
    @Published private(set) var defaultFrequency: HangoutFrequency = .monthly
    @Published private(set) var hasCompletedOnboarding: Bool = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Public API

    func apply(_ preferences: OnboardingPreferences) {
        favoriteActivities  = preferences.favoriteActivities
        defaultFrequency    = preferences.defaultFrequency
        hasCompletedOnboarding = true
        persist()
    }

    /// Returns whether a given activity type matches user interests.
    /// Used by SuggestionService to rank/filter activity suggestions.
    func score(for activity: ActivityType) -> Double {
        favoriteActivities.contains(activity) ? 1.0 : 0.4
    }

    /// Returns the preferred interval in days for a contact (falls back to default).
    func preferredInterval(for contactID: String? = nil) -> Int {
        // Future: per-contact overrides stored here
        defaultFrequency.days
    }

    // MARK: - Persistence

    private func persist() {
        let activityStrings = favoriteActivities.map(\.rawValue)
        defaults.set(activityStrings, forKey: Keys.activities)
        defaults.set(defaultFrequency.rawValue, forKey: Keys.defaultFrequency)
        defaults.set(true, forKey: Keys.onboardingDone)
    }

    private func load() {
        if let raw = defaults.stringArray(forKey: Keys.activities) {
            favoriteActivities = Set(raw.compactMap { ActivityType(rawValue: $0) })
        }
        if let raw = defaults.string(forKey: Keys.defaultFrequency),
           let freq = HangoutFrequency(rawValue: raw) {
            defaultFrequency = freq
        }
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingDone)
    }
}
