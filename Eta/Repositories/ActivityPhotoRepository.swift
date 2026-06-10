import Foundation
import SwiftData

final class ActivityPhotoRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Activity-scoped: all photos of this activity type regardless of friend.
    /// Used by the suggestions tab thumbnail.
    func photos(for activity: Activity) -> [ActivityPhoto] {
        let rawValue = activity.rawValue
        let descriptor = FetchDescriptor<ActivityPhoto>(
            predicate: #Predicate { $0.activityRawValue == rawValue },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Hangout-scoped: photos captured during one specific hangout.
    /// Used when a hangout-end notification is tapped (most precise match).
    func photos(for hangoutID: UUID) -> [ActivityPhoto] {
        let descriptor = FetchDescriptor<ActivityPhoto>(
            predicate: #Predicate { $0.hangoutID == hangoutID },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Friend-scoped: all photos from hangouts with a specific contact, newest first.
    /// Used by the nudge memory view.
    func photos(for contact: TrackedContact) -> [ActivityPhoto] {
        photos(forContactID: contact.id)
    }

    func photos(forContactID contactID: UUID) -> [ActivityPhoto] {
        let hangoutDescriptor = FetchDescriptor<ScheduledHangout>(
            predicate: #Predicate { $0.contact?.id == contactID }
        )
        let hangoutIDs = Set(
            ((try? modelContext.fetch(hangoutDescriptor)) ?? []).map { $0.id }
        )
        guard !hangoutIDs.isEmpty else { return [] }

        let photoDescriptor = FetchDescriptor<ActivityPhoto>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return ((try? modelContext.fetch(photoDescriptor)) ?? []).filter {
            guard let id = $0.hangoutID else { return false }
            return hangoutIDs.contains(id)
        }
    }

    /// All photos captured within the last `days` days. Used by SharedPhotoSyncService for upload.
    func recentPhotos(withinDays days: Int) -> [ActivityPhoto] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        let descriptor = FetchDescriptor<ActivityPhoto>(
            predicate: #Predicate { $0.capturedAt >= cutoff },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func add(_ photo: ActivityPhoto) throws {
        modelContext.insert(photo)
        try modelContext.save()
    }

    /// Saves a new photo, deleting any existing photos for the same hangout first.
    /// Use this for event-card captures where only one photo per hangout is kept.
    /// Pass hangoutID = nil to fall through to a plain add (no deletion).
    func save(imageData: Data, activity: Activity, hangoutID: UUID?) throws {
        if let hangoutID {
            let existing = photos(for: hangoutID)
            existing.forEach { modelContext.delete($0) }
        }
        let photo = ActivityPhoto(activity: activity, hangoutID: hangoutID, imageData: imageData)
        modelContext.insert(photo)
        try modelContext.save()
    }
}
