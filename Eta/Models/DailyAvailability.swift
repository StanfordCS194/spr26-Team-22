import Foundation

/// Groups all free-time blocks that belong to a single calendar day.
struct DailyAvailability: Codable, Equatable {

    /// The day these availability blocks apply to.
    let date: Date
    /// User-entered free-time windows on `date`.
    var blocks: [AvailabilityBlock]

    /// True when the user has entered at least one free-time block for this day.
    var isAvailable: Bool {
        !blocks.isEmpty
    }
}
