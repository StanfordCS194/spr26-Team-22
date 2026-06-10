//  Created by Lauren Hamilton on 5/12/26.
//
import Foundation
import Observation

/// Display-ready scheduled block for the availability grid.
struct ScheduledAvailabilityDisplayBlock: Identifiable {
    let id: UUID
    let label: String
    let startDate: Date
    let endDate: Date
}

/// Value-type snapshot of a scheduled hangout for availability display.
struct HangoutSlot {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let status: HangoutStatus
    let activity: String
    let contactFirstName: String?
}

/// Drives the Availability tab by combining saved free time, scheduled hangouts, and duration settings.
@Observable
final class AvailabilityViewModel {

    /// All saved free-time blocks, sorted by start time after loading or mutation.
    var blocks: [AvailabilityBlock] = []
    /// Upcoming hangouts as value-type snapshots — never holds live SwiftData references.
    var scheduledHangouts: [HangoutSlot] = []
    /// User-selected hangout length in minutes, constrained to 15-minute increments.
    var activityDurationMinutes: Int

    private let repository: AvailabilityRepository
    private let hangoutRepository: ScheduledHangoutRepository
    private let activityDurationSettings: ActivityDurationSettings
    private let tracker: AvailabilityPromptTracker
    private let analyticsService: AnalyticsService?
    private var sessionChangesCount: Int = 0
    private var sessionDidAdd: Bool = false
    private var sessionDidRemove: Bool = false
    private var sessionUsedRecurring: Bool = false

    /// Creates an availability view model with persistence, scheduled hangout lookup, and prompt tracking.
    init(
        repository: AvailabilityRepository,
        hangoutRepository: ScheduledHangoutRepository,
        activityDurationSettings: ActivityDurationSettings,
        tracker: AvailabilityPromptTracker = UserDefaultsAvailabilityPromptTracker(),
        analyticsService: AnalyticsService? = nil
    ) {
        self.repository = repository
        self.hangoutRepository = hangoutRepository
        self.activityDurationSettings = activityDurationSettings
        self.tracker = tracker
        self.analyticsService = analyticsService
        self.activityDurationMinutes = activityDurationSettings.minutes
    }

    /// Human-readable label for the currently selected hangout length.
    var activityDurationLabel: String {
        let minutes = activityDurationMinutes
        if minutes < 60 {
            return "\(minutes) min"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }

        return "\(hours) hr \(remainingMinutes) min"
    }

    /// Updates the shared hangout duration setting and mirrors the normalized value in observable state.
    func setActivityDurationMinutes(_ minutes: Int) {
        activityDurationSettings.minutes = minutes
        activityDurationMinutes = activityDurationSettings.minutes
    }

    /// Reloads saved free-time blocks and scheduled hangouts for display.
    func loadAvailability() async {
        do {
            blocks = try await repository.fetch()
                .sorted { $0.startTime < $1.startTime }
        } catch {
            blocks = []
        }

        do {
            scheduledHangouts = try hangoutRepository.fetchUpcoming()
                .sorted { $0.startDate < $1.startDate }
                .map { hangout in
                    let firstName: String?
                    if let contact = hangout.contact {
                        firstName = contact.givenName.isEmpty ? contact.name : contact.givenName
                    } else {
                        firstName = nil
                    }

                    return HangoutSlot(
                        id: hangout.id,
                        startDate: hangout.startDate,
                        endDate: hangout.endDate,
                        status: hangout.status,
                        activity: hangout.activity,
                        contactFirstName: firstName
                    )
                }
        } catch {
            scheduledHangouts = []
        }
    }

    /// Adds a new free-time block if its date range is valid and does not overlap another block.
    func addBlock(
        start: Date,
        end: Date,
        repeatsWeekly: Bool = false,
        repeatEndDate: Date? = nil
    ) -> Bool {

        guard end > start else {
            return false
        }

        let newBlock = AvailabilityBlock(
            startTime: start,
            endTime: end,
            repeatsWeekly: repeatsWeekly,
            repeatEndDate: repeatEndDate
        )

        guard !hasOverlap(newBlock) else {
            return false
        }

        blocks.append(newBlock)

        blocks.sort {
            $0.startTime < $1.startTime
        }
        saveBlocks()
        sessionChangesCount += 1
        sessionDidAdd = true
        if repeatsWeekly { sessionUsedRecurring = true }

        return true
    }

    /// Toggles the selected interval between available and unavailable.
    ///
    /// Scheduled hangouts cannot be toggled from the availability grid. Removing availability
    /// from the middle of a longer block splits that block around the removed interval.
    func toggleAvailability(
        during interval: DateInterval,
        repeatsWeekly: Bool = false,
        repeatEndDate: Date? = nil
    ) {
        guard !isScheduled(during: interval) else { return }

        if isFree(during: interval) {
            removeAvailability(during: interval)
            sessionDidRemove = true
        } else {
            blocks.append(AvailabilityBlock(
                startTime: interval.start,
                endTime: interval.end,
                repeatsWeekly: repeatsWeekly,
                repeatEndDate: repeatEndDate
            ))
            normalizeBlocks()
            sessionDidAdd = true
        }

        saveBlocks()
        sessionChangesCount += 1
        if repeatsWeekly { sessionUsedRecurring = true }
    }

    /// Removes a saved free-time block by identifier.
    func removeBlock(id: UUID) {
        blocks.removeAll { $0.id == id }
        saveBlocks()
        sessionChangesCount += 1
        sessionDidRemove = true
    }

    /// Call when the user leaves the availability tab. Fires one analytics event if any changes were made.
    func endSession() {
        guard sessionChangesCount > 0 else { return }
        let action: String
        switch (sessionDidAdd, sessionDidRemove) {
        case (true, true):  action = "both"
        case (true, false): action = "added"
        default:            action = "removed"
        }
        analyticsService?.logAvailabilitySessionCompleted(action: action, usedRecurring: sessionUsedRecurring)
        sessionChangesCount = 0
        sessionDidAdd = false
        sessionDidRemove = false
        sessionUsedRecurring = false
    }

    /// Returns whether the daily availability prompt should still be shown.
    func shouldShowPrompt(for date: Date) -> Bool {
        !tracker.hasProvidedAvailability(for: date)
    }

    /// Marks the daily availability prompt as completed.
    func userFinishedAvailability(for date: Date) {
        tracker.markAvailabilityProvided(for: date)
    }

    /// Returns free-time blocks whose start date falls on the requested day.
    func blocks(on date: Date) -> [AvailabilityBlock] {
        let calendar = Calendar.current
        return blocks
            .compactMap { $0.occurrence(on: date, calendar: calendar) }
            .sorted { $0.startTime < $1.startTime }
    }

    /// Returns true when the day has free or skipped recurring availability to display.
    func hasDisplayableAvailability(on date: Date) -> Bool {
        let calendar = Calendar.current
        return blocks.contains {
            $0.occurrence(on: date, calendar: calendar, includingSkipped: true) != nil
        }
    }

    /// Returns true when the day has scheduled hangouts to display on the availability grid.
    func hasScheduledHangout(on date: Date) -> Bool {
        !scheduledHangouts(on: date).isEmpty
    }

    /// Returns scheduled hangouts that overlap the requested day.
    func scheduledHangouts(on date: Date) -> [HangoutSlot] {
        guard let dayInterval = Calendar.current.dateInterval(of: .day, for: date) else {
            return []
        }

        return scheduledHangouts.filter {
            $0.status != .canceled &&
            $0.startDate < dayInterval.end &&
            $0.endDate > dayInterval.start
        }
    }

    /// Returns true when a free-time block overlaps any scheduled hangout in the supplied list.
    func isBlocked(
        _ block: AvailabilityBlock,
        scheduled: [HangoutSlot]
    ) -> Bool {
        scheduled.contains {
            $0.startDate < block.endTime &&
            $0.endDate > block.startTime
        }
    }

    /// Returns true when any saved free-time block overlaps the interval.
    func isFree(during interval: DateInterval) -> Bool {
        blocksForIntervalDay(interval).contains { block in
            block.startTime < interval.end &&
            block.endTime > interval.start
        }
    }

    /// Returns true when the interval overlaps weekly recurring availability.
    func isRecurringFree(during interval: DateInterval) -> Bool {
        blocksForIntervalDay(interval).contains { block in
            block.repeatsWeekly &&
            block.startTime < interval.end &&
            block.endTime > interval.start
        }
    }

    /// Returns the end date for recurring availability overlapping the interval, if one exists.
    func recurringEndDate(during interval: DateInterval) -> Date? {
        blocksForIntervalDay(interval).first { block in
            block.repeatsWeekly &&
            block.startTime < interval.end &&
            block.endTime > interval.start
        }?.repeatEndDate
    }

    /// Returns true when the interval overlaps a skipped recurring occurrence.
    func isSkippedRecurring(during interval: DateInterval) -> Bool {
        blocksForIntervalDay(interval, includingSkipped: true).contains { block in
            block.repeatsWeekly &&
            block.isSkipped(on: interval.start) &&
            block.startTime < interval.end &&
            block.endTime > interval.start
        }
    }

    /// Skips one occurrence of a recurring interval without stopping future repeats.
    func skipRecurringAvailability(during interval: DateInterval) {
        updateRecurringAvailability(during: interval, action: .skip)
        saveBlocks()
    }

    /// Restores one skipped recurring occurrence.
    func unskipRecurringAvailability(during interval: DateInterval) {
        updateRecurringAvailability(during: interval, action: .unskip)
        saveBlocks()
    }

    /// Stops a recurring interval from appearing again.
    func stopRecurringAvailability(during interval: DateInterval) {
        updateRecurringAvailability(during: interval, action: .stop)
        saveBlocks()
    }

    /// Returns true when any non-canceled scheduled hangout overlaps the interval.
    func isScheduled(during interval: DateInterval) -> Bool {
        scheduledHangouts.contains {
            $0.status != .canceled &&
            $0.startDate < interval.end &&
            $0.endDate > interval.start
        }
    }

    /// Builds display labels for scheduled hangouts overlapping the interval.
    func scheduledLabels(during interval: DateInterval) -> [String] {
        scheduledHangouts
            .filter {
                $0.status != .canceled &&
                $0.startDate < interval.end &&
                $0.endDate > interval.start
            }
            .map { scheduledLabel(for: $0) }
    }

    /// Returns scheduled hangouts clipped to the selected day for display as single blocks.
    func scheduledDisplayBlocks(on date: Date) -> [ScheduledAvailabilityDisplayBlock] {
        guard let dayInterval = Calendar.current.dateInterval(of: .day, for: date) else {
            return []
        }

        return scheduledHangouts
            .compactMap { hangout in
                guard hangout.status != .canceled,
                      hangout.startDate < dayInterval.end,
                      hangout.endDate > dayInterval.start
                else { return nil }

                let visibleStart = max(hangout.startDate, dayInterval.start)
                let visibleEnd = min(hangout.endDate, dayInterval.end)
                guard visibleEnd > visibleStart else { return nil }

                return ScheduledAvailabilityDisplayBlock(
                    id: hangout.id,
                    label: scheduledLabel(for: hangout),
                    startDate: visibleStart,
                    endDate: visibleEnd
                )
            }
    }

    private func scheduledLabel(for hangout: HangoutSlot) -> String {
        let timeRange = scheduledTimeRange(for: hangout)
        if let firstName = hangout.contactFirstName, !firstName.isEmpty {
            return "\(hangout.activity) with \(firstName) (\(timeRange))"
        }

        return "\(hangout.activity) (\(timeRange))"
    }

    private func scheduledTimeRange(for hangout: HangoutSlot) -> String {
        "\(timeFormatter.string(from: hangout.startDate))-\(timeFormatter.string(from: hangout.endDate))"
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter
    }

    /// Returns true when adding `newBlock` would overlap existing saved free time.
    private func hasOverlap(
        _ newBlock: AvailabilityBlock
    ) -> Bool {

        blocksForIntervalDay(DateInterval(start: newBlock.startTime, end: newBlock.endTime)).contains { block in
            newBlock.startTime < block.endTime &&
            newBlock.endTime > block.startTime
        }
    }

    /// Removes the interval from saved availability, preserving any free time before or after it.
    private func removeAvailability(during interval: DateInterval) {
        let calendar = Calendar.current
        blocks = blocks.flatMap { block -> [AvailabilityBlock] in
            guard let occurrence = block.occurrence(on: interval.start, calendar: calendar),
                  occurrence.startTime < interval.end,
                  occurrence.endTime > interval.start
            else {
                return [block]
            }

            var remaining: [AvailabilityBlock] = []
            if occurrence.startTime < interval.start,
               let start = sourceDate(for: occurrence.startTime, in: block, calendar: calendar),
               let end = sourceDate(for: interval.start, in: block, calendar: calendar) {
                remaining.append(AvailabilityBlock(
                    startTime: start,
                    endTime: end,
                    repeatsWeekly: block.repeatsWeekly,
                    repeatEndDate: block.repeatEndDate,
                    skippedOccurrenceDates: block.skippedOccurrenceDates
                ))
            }

            if interval.end < occurrence.endTime,
               let start = sourceDate(for: interval.end, in: block, calendar: calendar),
               let end = sourceDate(for: occurrence.endTime, in: block, calendar: calendar) {
                remaining.append(AvailabilityBlock(
                    startTime: start,
                    endTime: end,
                    repeatsWeekly: block.repeatsWeekly,
                    repeatEndDate: block.repeatEndDate,
                    skippedOccurrenceDates: block.skippedOccurrenceDates
                ))
            }
            return remaining
        }
    }

    /// Sorts saved blocks and merges adjacent or overlapping availability.
    private func normalizeBlocks() {
        let sorted = blocks.sorted { $0.startTime < $1.startTime }
        var merged: [AvailabilityBlock] = []

        for block in sorted {
            guard let last = merged.last else {
                merged.append(block)
                continue
            }

            if canMerge(last, block) {
                merged.removeLast()
                merged.append(AvailabilityBlock(
                    id: last.id,
                    startTime: last.startTime,
                    endTime: max(last.endTime, block.endTime),
                    repeatsWeekly: last.repeatsWeekly,
                    repeatEndDate: last.repeatEndDate,
                    skippedOccurrenceDates: last.skippedOccurrenceDates
                ))
            } else {
                merged.append(block)
            }
        }

        blocks = merged
    }

    /// Persists the current in-memory free-time blocks.
    private func saveBlocks() {
        let blocks = self.blocks
        Task {
            try? await repository.save(blocks)
        }
    }

    /// Returns saved blocks as concrete occurrences on the interval's start day.
    private func blocksForIntervalDay(
        _ interval: DateInterval,
        includingSkipped: Bool = false
    ) -> [AvailabilityBlock] {
        let calendar = Calendar.current
        return blocks.compactMap {
            $0.occurrence(
                on: interval.start,
                calendar: calendar,
                includingSkipped: includingSkipped
            )
        }
    }

    /// Maps an occurrence timestamp back onto the original saved block's source day.
    private func sourceDate(
        for occurrenceDate: Date,
        in block: AvailabilityBlock,
        calendar: Calendar
    ) -> Date? {
        let clock = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: occurrenceDate)
        return calendar.date(
            bySettingHour: clock.hour ?? 0,
            minute: clock.minute ?? 0,
            second: clock.second ?? 0,
            of: block.startTime
        )
    }

    /// Recurring and one-time blocks are only merged with blocks of the same recurrence pattern.
    private func canMerge(_ lhs: AvailabilityBlock, _ rhs: AvailabilityBlock) -> Bool {
        guard lhs.repeatsWeekly == rhs.repeatsWeekly,
              lhs.repeatEndDate == rhs.repeatEndDate,
              lhs.skippedOccurrenceDates == rhs.skippedOccurrenceDates,
              lhs.startTime <= rhs.startTime,
              rhs.startTime <= lhs.endTime
        else { return false }

        if lhs.repeatsWeekly {
            let calendar = Calendar.current
            return calendar.component(.weekday, from: lhs.startTime) == calendar.component(.weekday, from: rhs.startTime)
        }

        return Calendar.current.isDate(lhs.startTime, inSameDayAs: rhs.startTime)
    }

    private enum RecurringUpdateAction {
        case skip
        case unskip
        case stop
    }

    /// Applies a skip or stop action to only the selected slice of a recurring block.
    private func updateRecurringAvailability(
        during interval: DateInterval,
        action: RecurringUpdateAction
    ) {
        let calendar = Calendar.current
        let skippedDay = calendar.startOfDay(for: interval.start)

        blocks = blocks.flatMap { block -> [AvailabilityBlock] in
            guard block.repeatsWeekly,
                  let occurrence = block.occurrence(
                    on: interval.start,
                    calendar: calendar,
                    includingSkipped: true
                  ),
                  occurrence.startTime < interval.end,
                  occurrence.endTime > interval.start
            else {
                return [block]
            }

            var updated: [AvailabilityBlock] = []

            if occurrence.startTime < interval.start,
               let start = sourceDate(for: occurrence.startTime, in: block, calendar: calendar),
               let end = sourceDate(for: interval.start, in: block, calendar: calendar) {
                updated.append(AvailabilityBlock(
                    startTime: start,
                    endTime: end,
                    repeatsWeekly: true,
                    repeatEndDate: block.repeatEndDate,
                    skippedOccurrenceDates: block.skippedOccurrenceDates
                ))
            }

            if action != .stop,
               let start = sourceDate(for: interval.start, in: block, calendar: calendar),
               let end = sourceDate(for: interval.end, in: block, calendar: calendar) {
                var skippedDates = block.skippedOccurrenceDates
                if action == .skip,
                   !skippedDates.contains(where: { calendar.isDate($0, inSameDayAs: skippedDay) }) {
                    skippedDates.append(skippedDay)
                } else if action == .unskip {
                    skippedDates.removeAll { calendar.isDate($0, inSameDayAs: skippedDay) }
                }

                updated.append(AvailabilityBlock(
                    startTime: start,
                    endTime: end,
                    repeatsWeekly: true,
                    repeatEndDate: block.repeatEndDate,
                    skippedOccurrenceDates: skippedDates
                ))
            }

            if interval.end < occurrence.endTime,
               let start = sourceDate(for: interval.end, in: block, calendar: calendar),
               let end = sourceDate(for: occurrence.endTime, in: block, calendar: calendar) {
                updated.append(AvailabilityBlock(
                    startTime: start,
                    endTime: end,
                    repeatsWeekly: true,
                    repeatEndDate: block.repeatEndDate,
                    skippedOccurrenceDates: block.skippedOccurrenceDates
                ))
            }

            return updated
        }

        normalizeBlocks()
    }
}
