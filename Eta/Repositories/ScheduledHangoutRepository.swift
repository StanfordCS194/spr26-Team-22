import Foundation
import SwiftData

extension Notification.Name {
    /// Posted after scheduled hangouts are added, removed, or have status changes relevant to availability.
    static let scheduledHangoutsDidChange = Notification.Name("scheduledHangoutsDidChange")
}

/// SwiftData repository for hangouts that have been scheduled from suggestions.
final class ScheduledHangoutRepository {
    private let modelContext: ModelContext

    /// Creates a repository backed by the supplied SwiftData model context.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Inserts a scheduled hangout and notifies availability views that busy time changed.
    func add(_ hangout: ScheduledHangout) throws {
        guard try !hasOverlappingHangout(start: hangout.startDate, end: hangout.endDate) else {
            throw ScheduledHangoutRepositoryError.overlappingHangout
        }
        modelContext.insert(hangout)
        try modelContext.save()
        NotificationCenter.default.post(name: .scheduledHangoutsDidChange, object: nil)
    }

    /// Returns true when a non-canceled hangout already occupies any part of the interval.
    /// Pass `excludingID` to ignore a specific hangout (e.g. the one being edited).
    func hasOverlappingHangout(start: Date, end: Date, excludingID: UUID? = nil) throws -> Bool {
        guard end > start else { return false }

        return try fetchUpcoming().contains {
            $0.id != excludingID &&
            $0.status != .canceled &&
            $0.startDate < end &&
            $0.endDate > start
        }
    }

    /// Deletes a scheduled hangout and notifies availability views that busy time changed.
    func remove(_ hangout: ScheduledHangout) throws {
        modelContext.delete(hangout)
        try modelContext.save()
        NotificationCenter.default.post(name: .scheduledHangoutsDidChange, object: nil)
    }

    /// Fetches all scheduled hangouts sorted by creation time.
    func fetchAll() throws -> [ScheduledHangout] {
        let descriptor = FetchDescriptor<ScheduledHangout>(
            sortBy: [SortDescriptor(\.scheduledAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches hangouts whose scheduled time has not fully elapsed.
    func fetchUpcoming() throws -> [ScheduledHangout] {
        try fetchAll().filter { $0.endDate > .now }
    }
}

enum ScheduledHangoutRepositoryError: Error {
    case overlappingHangout
}
