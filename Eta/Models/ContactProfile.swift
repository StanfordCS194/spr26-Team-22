import Foundation
import SwiftData

/// Per-contact preference and pattern record.
///
/// Explicit preferences (liked/disliked activities, notes) are the source of truth
/// and are set only by the user. Inferred patterns from hangout history surface as
/// a `pendingInference` that requires explicit confirmation before influencing suggestions.
@Model
final class ContactProfile {
    /// The TrackedContact this profile belongs to.
    var contactIDString: String
    /// CSV of Activity.rawValue strings the user has confirmed they enjoy with this person.
    var likedActivityRaws: String
    /// CSV of Activity.rawValue strings the user has marked as not a good fit for this relationship.
    var dislikedActivityRaws: String
    /// Activity.rawValue inferred from hangout history, awaiting user confirmation.
    /// nil when no inference is pending or the user has already responded.
    var pendingInferenceRaw: String?
    /// Free-text relational context set by the user ("prefers mornings", "she's vegan").
    var notes: String
    var lastUpdated: Date

    // MARK: - Typed accessors

    var contactID: UUID? { UUID(uuidString: contactIDString) }

    var likedActivities: [Activity] {
        likedActivityRaws.isEmpty ? [] :
            likedActivityRaws.split(separator: ",").compactMap { Activity(rawValue: String($0)) }
    }

    var dislikedActivities: [Activity] {
        dislikedActivityRaws.isEmpty ? [] :
            dislikedActivityRaws.split(separator: ",").compactMap { Activity(rawValue: String($0)) }
    }

    var pendingInference: Activity? {
        guard let raw = pendingInferenceRaw else { return nil }
        return Activity(rawValue: raw)
    }

    // MARK: - Mutation helpers

    func addLike(_ activity: Activity) {
        var liked = likedActivities
        var disliked = dislikedActivities
        if !liked.contains(activity) { liked.append(activity) }
        disliked.removeAll { $0 == activity }
        likedActivityRaws = liked.map(\.rawValue).joined(separator: ",")
        dislikedActivityRaws = disliked.map(\.rawValue).joined(separator: ",")
        lastUpdated = .now
    }

    func addDislike(_ activity: Activity) {
        var liked = likedActivities
        var disliked = dislikedActivities
        if !disliked.contains(activity) { disliked.append(activity) }
        liked.removeAll { $0 == activity }
        likedActivityRaws = liked.map(\.rawValue).joined(separator: ",")
        dislikedActivityRaws = disliked.map(\.rawValue).joined(separator: ",")
        lastUpdated = .now
    }

    /// Removes an activity from both liked and disliked lists, returning it to neutral.
    func removeSentiment(for activity: Activity) {
        var liked = likedActivities
        var disliked = dislikedActivities
        liked.removeAll { $0 == activity }
        disliked.removeAll { $0 == activity }
        likedActivityRaws = liked.map(\.rawValue).joined(separator: ",")
        dislikedActivityRaws = disliked.map(\.rawValue).joined(separator: ",")
        lastUpdated = .now
    }

    init(contactID: UUID) {
        self.contactIDString = contactID.uuidString
        self.likedActivityRaws = ""
        self.dislikedActivityRaws = ""
        self.pendingInferenceRaw = nil
        self.notes = ""
        self.lastUpdated = .now
    }
}
