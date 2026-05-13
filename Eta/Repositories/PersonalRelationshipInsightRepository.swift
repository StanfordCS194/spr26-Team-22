import Foundation
import SwiftData

final class PersonalRelationshipInsightRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func add(_ insight: PersonalRelationshipInsight) throws {
        modelContext.insert(insight)
        try modelContext.save()
    }

    func save() throws {
        try modelContext.save()
    }

    func fetchAll() throws -> [PersonalRelationshipInsight] {
        let descriptor = FetchDescriptor<PersonalRelationshipInsight>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Returns the most recent undismissed insight generated within the past 12 hours, if any.
    func fetchTodaysInsight() throws -> PersonalRelationshipInsight? {
        let cutoff = Date().addingTimeInterval(-12 * 3600)
        return try fetchAll().first {
            $0.dismissedAt == nil && $0.generatedAt >= cutoff
        }
    }

    /// Dismisses an insight and saves.
    func dismiss(_ insight: PersonalRelationshipInsight) throws {
        insight.dismissedAt = .now
        insight.consecutiveDismissals += 1
        try modelContext.save()
    }
}
