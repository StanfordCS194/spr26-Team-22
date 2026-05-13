import Foundation
import SwiftData

final class GoalRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func add(_ goal: Goal) throws {
        modelContext.insert(goal)
        try modelContext.save()
    }

    func remove(_ goal: Goal) throws {
        modelContext.delete(goal)
        try modelContext.save()
    }

    func save() throws {
        try modelContext.save()
    }

    func fetchAll() throws -> [Goal] {
        let descriptor = FetchDescriptor<Goal>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchActive() throws -> [Goal] {
        try fetchAll().filter { !$0.isPaused && $0.status != .achieved }
    }
}
