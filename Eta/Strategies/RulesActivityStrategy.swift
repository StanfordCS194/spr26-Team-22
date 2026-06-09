import Foundation

/// Selects a hangout activity using deterministic rules.
///
/// Picks a random activity from the hardcoded Activity enum pool, excluding
/// any activities the user has marked as "not a fit" for this contact.
/// Falls back to the full pool if all activities have been disliked.
///
/// ActivityType = Activity (the structured enum). The enum value is erased to
/// its description String before constructing ActivityProposal.
final class RulesActivityStrategy: ActivityStrategy {
    typealias ActivityType = Activity

    private let profileService: ContactProfileService

    init(profileService: ContactProfileService) {
        self.profileService = profileService
    }

    func propose(
        for health: RelationshipHealth,
        context: PromptContext
    ) async throws -> ActivityProposal? {
        let isRemote = health.contact.isRemote
        let disliked = profileService.profile(for: health.contact).dislikedActivities
        let previouslyShown = Set(context.previouslySuggestedActivities)
        var candidates = Activity.allCases.filter {
            !disliked.contains($0) && $0.isRemote == isRemote && !previouslyShown.contains($0.description)
        }
        // Relax previously-shown constraint before the disliked constraint so the inbox never empties
        // simply because all unseen activities have been exhausted in a single session.
        if candidates.isEmpty {
            candidates = Activity.allCases.filter { !disliked.contains($0) && $0.isRemote == isRemote }
        }
        if candidates.isEmpty {
            candidates = Activity.allCases.filter { $0.isRemote == isRemote }
        }
        guard let activity = candidates.randomElement() else { return nil }
        return ActivityProposal(
            activityDescription: activity.description,
            reason: reason(for: health)
        )
    }

    // MARK: - Private

    private func reason(for health: RelationshipHealth) -> String {
        guard let days = health.daysSinceLastHangout else {
            return "You two haven't hung out yet"
        }
        switch days {
        case 7..<14:
            return "You haven't hung out in over a week"
        case 14..<30:
            return "It's been \(days) days since your last hangout"
        default:
            return "You haven't hung out in over a month"
        }
    }
}
