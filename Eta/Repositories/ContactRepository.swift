import Foundation
import SwiftData

/// Handles all SwiftData persistence for TrackedContact.
///
/// This is the only type that touches ModelContext directly.
/// Services and ViewModels must go through this repository to read or write contacts.
final class ContactRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Inserts a new TrackedContact and saves.
    func add(_ contact: TrackedContact) throws {
        modelContext.insert(contact)
        try modelContext.save()
    }

    /// Deletes a TrackedContact and saves.
    func remove(_ contact: TrackedContact) throws {
        modelContext.delete(contact)
        try modelContext.save()
    }

    /// Persists any pending changes to tracked contacts.
    func save() throws {
        try modelContext.save()
    }

    /// Returns all persisted TrackedContacts, sorted by the date they were added (oldest first).
    func fetchAll() throws -> [TrackedContact] {
        let descriptor = FetchDescriptor<TrackedContact>(
            sortBy: [SortDescriptor(\.addedAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }
}

