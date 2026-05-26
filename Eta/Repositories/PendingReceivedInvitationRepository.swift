import Foundation
import SwiftData

final class PendingReceivedInvitationRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func add(_ invite: PendingReceivedInvitation) throws {
        modelContext.insert(invite)
        try modelContext.save()
    }

    func fetchAll() throws -> [PendingReceivedInvitation] {
        try modelContext.fetch(FetchDescriptor<PendingReceivedInvitation>())
    }

    func exists(id: String) -> Bool {
        let descriptor = FetchDescriptor<PendingReceivedInvitation>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? modelContext.fetch(descriptor).first) != nil
    }

    func delete(id: String) throws {
        let descriptor = FetchDescriptor<PendingReceivedInvitation>(
            predicate: #Predicate { $0.id == id }
        )
        guard let record = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    func deleteExpired() throws {
        let now = Date()
        let descriptor = FetchDescriptor<PendingReceivedInvitation>(
            predicate: #Predicate { $0.endTime < now }
        )
        let expired = try modelContext.fetch(descriptor)
        guard !expired.isEmpty else { return }
        expired.forEach { modelContext.delete($0) }
        try modelContext.save()
    }
}
