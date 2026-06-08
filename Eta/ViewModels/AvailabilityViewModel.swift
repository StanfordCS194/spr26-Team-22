//  Created by Lauren Hamilton on 5/12/26.
//
import Foundation
import Observation

struct HangoutSlot {
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

    /// Creates an availability view model with persistence, scheduled hangout lookup, and prompt tracking.
    init(
        repository: AvailabilityRepository,
        hangoutRepository: ScheduledHangoutRepository,
        activityDurationSettings: ActivityDurationSettings,
        tracker: AvailabilityPromptTracker = UserDefaultsAvailabilityPromptTracker()
    ) {
        self.repository = repository
        self.hangoutRepository = hangoutRepository
        self.activityDurationSettings = activityDurationSettings
        self.tracker = tracker
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
                .map { h in
                    let firstName: String?
                    if let contact = h.contact {
                        firstName = contact.givenName.isEmpty ? contact.name : contact.givenName
                    } else {
                        firstName = nil
                    }
                    return HangoutSlot(
                        startDate: h.startDate,
                        endDate: h.endDate,
                        status: h.status,
                        activity: h.activity,
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
        end: Date
    ) -> Bool {

        guard end > start else {
            return false
        }

        let newBlock = AvailabilityBlock(
            startTime: start,
            endTime: end
        )

        guard !hasOverlap(newBlock) else {
            return false
        }

        blocks.append(newBlock)

        blocks.sort {
            $0.startTime < $1.startTime
        }
        saveBlocks()

        return true
    }

    /// Toggles the selected interval between available and unavailable.
    ///
    /// Scheduled hangouts cannot be toggled from the availability grid. Removing availability
    /// from the middle of a longer block splits that block around the removed interval.
    func toggleAvailability(during interval: DateInterval) {
        guard !isScheduled(during: interval) else { return }

        if isFree(during: interval) {
            removeAvailability(during: interval)
        } else {
            blocks.append(AvailabilityBlock(startTime: interval.start, endTime: interval.end))
            normalizeBlocks()
        }

        saveBlocks()
    }

    /// Removes a saved free-time block by identifier.
    func removeBlock(id: UUID) {
        blocks.removeAll { $0.id == id }
        saveBlocks()
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
        blocks.filter {
            Calendar.current.isDate($0.startTime, inSameDayAs: date)
        }
    }

    /// Returns scheduled hangouts whose start date falls on the requested day.
    func scheduledHangouts(on date: Date) -> [HangoutSlot] {
        scheduledHangouts.filter {
            Calendar.current.isDate($0.startDate, inSameDayAs: date)
        }
    }

    /// Returns true when a free-time block overlaps any scheduled hangout in the supplied list.
    func isBlocked(_ block: AvailabilityBlock, scheduled: [HangoutSlot]) -> Bool {
        scheduled.contains {
            $0.startDate < block.endTime &&
            $0.endDate > block.startTime
        }
    }

    /// Returns true when any saved free-time block overlaps the interval.
    func isFree(during interval: DateInterval) -> Bool {
        blocks.contains { block in
            block.startTime < interval.end &&
            block.endTime > interval.start
        }
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
            .map { slot in
                if let firstName = slot.contactFirstName, !firstName.isEmpty {
                    return "\(slot.activity) with \(firstName)"
                }
                return slot.activity
            }
    }

    /// Returns true when adding `newBlock` would overlap existing saved free time.
    private func hasOverlap(
        _ newBlock: AvailabilityBlock
    ) -> Bool {

        blocks.contains { block in
            newBlock.startTime < block.endTime &&
            newBlock.endTime > block.startTime
        }
    }

    /// Removes the interval from saved availability, preserving any free time before or after it.
    private func removeAvailability(during interval: DateInterval) {
        blocks = blocks.flatMap { block -> [AvailabilityBlock] in
            guard block.startTime < interval.end, block.endTime > interval.start else {
                return [block]
            }

            var remaining: [AvailabilityBlock] = []
            if block.startTime < interval.start {
                remaining.append(AvailabilityBlock(startTime: block.startTime, endTime: interval.start))
            }
            if interval.end < block.endTime {
                remaining.append(AvailabilityBlock(startTime: interval.end, endTime: block.endTime))
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

            if block.startTime <= last.endTime {
                merged.removeLast()
                merged.append(AvailabilityBlock(
                    id: last.id,
                    startTime: last.startTime,
                    endTime: max(last.endTime, block.endTime)
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
}
