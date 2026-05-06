import Foundation
import SwiftData

/// Handles all SwiftData persistence for FeedbackEntry.
///
/// This is the only type that reads or writes FeedbackEntry via ModelContext.
/// ContextSources and Services must go through this repository.
final class FeedbackRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Inserts a new FeedbackEntry and saves.
    func add(_ entry: FeedbackEntry) throws {
        modelContext.insert(entry)
        try modelContext.save()
    }

    /// Returns all feedback entries for the given contact, sorted newest first.
    func fetch(for contact: TrackedContact) throws -> [FeedbackEntry] {
        let contactID = contact.id
        let descriptor = FetchDescriptor<FeedbackEntry>(
            predicate: #Predicate { $0.contactID == contactID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Returns all feedback entries across all contacts, sorted newest first.
    func fetchAll() throws -> [FeedbackEntry] {
        let descriptor = FetchDescriptor<FeedbackEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
}
