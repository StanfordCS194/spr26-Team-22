import Foundation

/// Computed health state for a single tracked contact.
/// Produced by RelationshipService; consumed by SuggestionStrategy.
struct RelationshipHealth {
    var contact: TrackedContact
    /// Date of the most recent hangout event found in the look-back window.
    var lastHangoutDate: Date?
    /// Number of hangouts within the look-back window (default: 90 days).
    var hangoutCount: Int
    /// Ranking score — higher means more overdue for a hangout.
    var score: Double

    /// Convenience: whole days elapsed since the last hangout, or nil if none on record.
    var daysSinceLastHangout: Int? {
        guard let last = lastHangoutDate else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: .now).day
    }
}
