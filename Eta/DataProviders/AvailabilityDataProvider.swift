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
        return all.filter {
            calendar.isDate($0.startTime, inSameDayAs: date)
        }
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

        return all
            .flatMap { block -> [DateInterval] in
                guard block.endTime > now, block.startTime < searchEnd else { return [] }
                let start = roundedSlotStart(for: max(block.startTime, now), calendar: calendar)
                let interval = DateInterval(start: start, end: block.endTime)
                return subtractScheduledHangouts(from: interval, scheduled: scheduled)
                    .compactMap { freeInterval -> DateInterval? in
                        let roundedStart = roundedSlotStart(for: freeInterval.start, calendar: calendar)
                        guard freeInterval.end.timeIntervalSince(roundedStart) >= activityDuration else {
                            return nil
                        }
                        return DateInterval(start: roundedStart, duration: activityDuration)
                    }
            }
            .sorted { $0.start < $1.start }
            .prefix(maximumCount)
            .map { $0 }
    }

    /// Rounds availability starts up to the next 15-minute boundary for cleaner suggestions.
    private func roundedSlotStart(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.minute, .second, .nanosecond], from: date)
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        let nanosecond = components.nanosecond ?? 0
        let remainder = minute % 15

        guard remainder != 0 || second != 0 || nanosecond != 0 else {
            return date
        }

        let minutesToAdd = remainder == 0 ? 15 : 15 - remainder
        guard let rounded = calendar.date(byAdding: .minute, value: minutesToAdd, to: date) else {
            return date
        }

        return calendar.date(
            bySettingHour: calendar.component(.hour, from: rounded),
            minute: calendar.component(.minute, from: rounded),
            second: 0,
            of: rounded
        ) ?? rounded
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
