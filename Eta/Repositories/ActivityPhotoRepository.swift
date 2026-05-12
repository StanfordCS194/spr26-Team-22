import Foundation
import SwiftData

final class ActivityPhotoRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func photos(for activity: Activity) -> [ActivityPhoto] {
        let rawValue = activity.rawValue
        let descriptor = FetchDescriptor<ActivityPhoto>(
            predicate: #Predicate { $0.activityRawValue == rawValue },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func add(_ photo: ActivityPhoto) throws {
        modelContext.insert(photo)
        try modelContext.save()
    }
}
