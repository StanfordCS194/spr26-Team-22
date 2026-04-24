import Foundation
import SwiftData

final class ScheduledHangoutRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func add(_ hangout: ScheduledHangout) throws {
        modelContext.insert(hangout)
        try modelContext.save()
    }

    func remove(_ hangout: ScheduledHangout) throws {
        modelContext.delete(hangout)
        try modelContext.save()
    }

    func fetchAll() throws -> [ScheduledHangout] {
        let descriptor = FetchDescriptor<ScheduledHangout>(
            sortBy: [SortDescriptor(\.scheduledAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchUpcoming() throws -> [ScheduledHangout] {
        try fetchAll().filter { $0.startDate > .now }
    }
}
