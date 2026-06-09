//  Created by Lauren Hamilton on 5/12/26.
//

import Foundation

/// A user-entered span of time when the user is free to schedule hangouts.
struct AvailabilityBlock: Identifiable, Codable, Equatable {

    private enum CodingKeys: String, CodingKey {
        case id
        case startTime
        case endTime
        case repeatsWeekly
        case repeatEndDate
        case skippedOccurrenceDates
    }

    /// Stable identifier used by SwiftUI lists and removal actions.
    let id: UUID
    /// The beginning of the free-time window.
    var startTime: Date
    /// The end of the free-time window.
    var endTime: Date
    /// Whether this free-time window repeats every week on the same weekday.
    var repeatsWeekly: Bool
    /// The final date this recurring block should appear. Nil means it repeats indefinitely.
    var repeatEndDate: Date?
    /// Start-of-day dates for recurring occurrences the user skipped.
    var skippedOccurrenceDates: [Date]

    /// Creates a free-time block, defaulting to a new identifier for newly entered availability.
    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        repeatsWeekly: Bool = false,
        repeatEndDate: Date? = nil,
        skippedOccurrenceDates: [Date] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.repeatsWeekly = repeatsWeekly
        self.repeatEndDate = repeatEndDate
        self.skippedOccurrenceDates = skippedOccurrenceDates
    }

    /// Decodes older saved availability blocks as one-time blocks.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.startTime = try container.decode(Date.self, forKey: .startTime)
        self.endTime = try container.decode(Date.self, forKey: .endTime)
        self.repeatsWeekly = try container.decodeIfPresent(Bool.self, forKey: .repeatsWeekly) ?? false
        self.repeatEndDate = try container.decodeIfPresent(Date.self, forKey: .repeatEndDate)
        self.skippedOccurrenceDates = try container.decodeIfPresent([Date].self, forKey: .skippedOccurrenceDates) ?? []
    }

    /// Returns the concrete occurrence of this block on `date`, handles recurring AvailabilityBlock
    func occurrence(
        on date: Date,
        calendar: Calendar = .current,
        includingSkipped: Bool = false
    ) -> AvailabilityBlock? {
        if !repeatsWeekly {
            return calendar.isDate(startTime, inSameDayAs: date) ? self : nil
        }

        let occurrenceDay = calendar.startOfDay(for: date)
        let firstRepeatDay = calendar.startOfDay(for: startTime)
        guard occurrenceDay >= firstRepeatDay else { return nil }

        if let repeatEndDate = repeatEndDate {
            let repeatEndDay = calendar.startOfDay(for: repeatEndDate)
            guard occurrenceDay <= repeatEndDay else { return nil }
        }

        let sourceComponents = calendar.dateComponents([.weekday], from: startTime)
        let dateComponents = calendar.dateComponents([.weekday], from: date)
        guard sourceComponents.weekday == dateComponents.weekday else { return nil }
        guard includingSkipped || !isSkipped(on: date, calendar: calendar) else { return nil }

        let startClock = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: startTime)
        let endClock = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: endTime)

        guard let occurrenceStart = calendar.date(
            bySettingHour: startClock.hour ?? 0,
            minute: startClock.minute ?? 0,
            second: startClock.second ?? 0,
            of: date
        ) else { return nil }

        let occurrenceEnd: Date
        if let end = calendar.date(
            bySettingHour: endClock.hour ?? 0,
            minute: endClock.minute ?? 0,
            second: endClock.second ?? 0,
            of: date
        ), end > occurrenceStart {
            occurrenceEnd = end
        } else {
            occurrenceEnd = calendar.date(byAdding: .day, value: 1, to: occurrenceStart) ?? endTime
        }

        return AvailabilityBlock(
            id: id,
            startTime: occurrenceStart,
            endTime: occurrenceEnd,
            repeatsWeekly: true,
            repeatEndDate: repeatEndDate,
            skippedOccurrenceDates: skippedOccurrenceDates
        )
    }

    /// Returns true when this recurring block was skipped on the supplied date.
    func isSkipped(on date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return skippedOccurrenceDates.contains { calendar.isDate($0, inSameDayAs: day) }
    }
}
