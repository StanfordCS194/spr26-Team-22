//
//  UserDefaultsAvailabilityPromptTracker.swift
//  Eta
//
//  Created by Lauren Hamilton on 5/12/26.
//

import Foundation

/// Persists day-level availability prompt completion in `UserDefaults`.
final class UserDefaultsAvailabilityPromptTracker: AvailabilityPromptTracker {

    private let defaults = UserDefaults.standard

    private let keyPrefix = "availability-provided-"

    /// Returns true when the user has already completed the availability prompt for `date`.
    func hasProvidedAvailability(for date: Date) -> Bool {
        let key = storageKey(for: date)
        return defaults.bool(forKey: key)
    }

    /// Records that the user has completed the availability prompt for `date`.
    func markAvailabilityProvided(for date: Date) {
        let key = storageKey(for: date)
        defaults.set(true, forKey: key)
    }

    /// Builds the per-day storage key used by the prompt tracker.
    private func storageKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return keyPrefix + formatter.string(from: date)
    }
}
