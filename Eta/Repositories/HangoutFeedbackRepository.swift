import Foundation
import SwiftData

/// SwiftData repository for user-submitted post-hangout feedback.
final class HangoutFeedbackRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Fetches all feedback entries sorted by submission date, newest first.
    func fetchAll() throws -> [HangoutFeedback] {
        let descriptor = FetchDescriptor<HangoutFeedback>(
            sortBy: [SortDescriptor(\.submittedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Returns the feedback entry for a specific hangout, or nil if none was submitted.
    func fetch(for hangoutID: UUID) throws -> HangoutFeedback? {
        let descriptor = FetchDescriptor<HangoutFeedback>(
            predicate: #Predicate { $0.hangoutID == hangoutID }
        )
        return try modelContext.fetch(descriptor).first
    }

    func add(_ feedback: HangoutFeedback) throws {
        modelContext.insert(feedback)
        try modelContext.save()
    }
}
