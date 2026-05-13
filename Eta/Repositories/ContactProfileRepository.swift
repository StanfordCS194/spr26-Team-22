import Foundation
import SwiftData

final class ContactProfileRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchOrCreate(for contactID: UUID) -> ContactProfile {
        if let existing = fetch(for: contactID) { return existing }
        let profile = ContactProfile(contactID: contactID)
        modelContext.insert(profile)
        try? modelContext.save()
        return profile
    }

    func fetch(for contactID: UUID) -> ContactProfile? {
        let idString = contactID.uuidString
        let descriptor = FetchDescriptor<ContactProfile>(
            predicate: #Predicate { $0.contactIDString == idString }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func save() throws {
        try modelContext.save()
    }
}
