//  Created by Lauren Hamilton on 5/12/26.


import Foundation

/// Validates whether a free-time block is long enough to support the shortest hangout.
struct SchedulingEngineA {

    /// Returns true when the block is at least the minimum supported activity duration.
    func qualifies(_ block: AvailabilityBlock) -> Bool {
        let duration = block.endTime.timeIntervalSince(block.startTime)

        return duration >= TimeInterval(ActivityDurationSettings.minimumMinutes * 60)
    }
}

/// Converts saved availability blocks into concrete suggestion-ready time intervals.
final class AvailabilityDataProvider: AvailabilityProvider {

    private let repository: AvailabilityRepository
    private let hangoutRepository: ScheduledHangoutRepository
    private let activityDurationSettings: ActivityDurationSettings

    /// Creates a provider that reads availability, subtracts scheduled hangouts, and applies duration preferences.
    init(
        repository: AvailabilityRepository,
        hangoutRepository: ScheduledHangoutRepository,
        activityDurationSettings: ActivityDurationSettings
    ) {
        self.repository = repository
        self.hangoutRepository = hangoutRepository
        self.activityDurationSettings = activityDurationSettings
    }

    /// Returns user-defined free time blocks for a given date.
    func fetchAvailability(for date: Date) async throws -> [AvailabilityBlock] {
        let all = try await repository.fetch()

        let calendar = Calendar.current
        return all
            .compactMap { $0.occurrence(on: date, calendar: calendar) }
            .sorted { $0.startTime < $1.startTime }
    }

    /// Returns the earliest schedulable intervals in the near-term window.
    ///
    /// Each returned interval is exactly the current activity duration. Longer free blocks are
    /// trimmed to their first schedulable slice so the remaining free time can still be reused.
    func findAvailableSlots(
        within lookAheadDays: Int = 3,
        maximumCount: Int = 3
    ) async throws -> [DateInterval] {
        let all = try await repository.fetch()
        let scheduled = (try? hangoutRepository.fetchUpcoming()) ?? []
        let calendar = Calendar.current
        let now = Date()
        let searchEnd = calendar.date(byAdding: .day, value: lookAheadDays, to: now) ?? now
        let activityDuration = activityDurationSettings.duration
        let availableBlocks = expandAvailability(all, from: now, through: searchEnd, calendar: calendar)

        return availableBlocks
            .flatMap { block -> [DateInterval] in
                guard block.endTime > now, block.startTime < searchEnd else { return [] }
                let interval = DateInterval(start: max(block.startTime, now), end: block.endTime)
                return subtractScheduledHangouts(from: interval, scheduled: scheduled)
                    .filter { $0.duration >= activityDuration }
                    .map { DateInterval(start: $0.start, duration: activityDuration) }
            }
            .sorted { $0.start < $1.start }
            .prefix(maximumCount)
            .map { $0 }
    }

    /// Expands saved one-time and weekly recurring blocks into concrete blocks for the search window.
    private func expandAvailability(
        _ blocks: [AvailabilityBlock],
        from start: Date,
        through end: Date,
        calendar: Calendar
    ) -> [AvailabilityBlock] {
        var date = calendar.startOfDay(for: start)
        let finalDate = calendar.startOfDay(for: end)
        var expanded: [AvailabilityBlock] = []

        while date <= finalDate {
            expanded.append(contentsOf: blocks.compactMap { $0.occurrence(on: date, calendar: calendar) })
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }

        return expanded.sorted { $0.startTime < $1.startTime }
    }

    /// Removes already scheduled hangouts from a candidate free interval.
    private func subtractScheduledHangouts(
        from interval: DateInterval,
        scheduled: [ScheduledHangout]
    ) -> [DateInterval] {
        let busyIntervals = scheduled
            .filter { $0.status != .canceled }
            .map { DateInterval(start: $0.startDate, end: $0.endDate) }
            .filter { $0.intersects(interval) }
            .sorted { $0.start < $1.start }

        var free: [DateInterval] = []
        var cursor = interval.start

        for busy in busyIntervals {
            let busyStart = max(busy.start, interval.start)
            let busyEnd = min(busy.end, interval.end)

            if cursor < busyStart {
                free.append(DateInterval(start: cursor, end: busyStart))
            }

            if cursor < busyEnd {
                cursor = busyEnd
            }
        }

        if cursor < interval.end {
            free.append(DateInterval(start: cursor, end: interval.end))
        }

        return free
    }
}
