//  Created by Lauren Hamilton on 5/12/26.
import Foundation

/// Tracks whether the user has already responded to the availability prompt for a day.
protocol AvailabilityPromptTracker {
    /// Returns true when availability has already been indicated for the given day.
    func hasProvidedAvailability(for date: Date) -> Bool
    /// Marks the given day as having completed the availability prompt.
    func markAvailabilityProvided(for date: Date)
}
