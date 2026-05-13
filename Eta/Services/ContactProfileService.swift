import Foundation

/// Manages per-contact activity preferences and pattern inference.
///
/// Explicit preferences (likes/dislikes) are the source of truth and only change
/// on explicit user action. Inferred patterns from hangout history surface as a
/// `pendingInferenceRaw` on ContactProfile, requiring user confirmation before
/// influencing suggestions.
final class ContactProfileService {
    private let profileRepository: ContactProfileRepository

    init(profileRepository: ContactProfileRepository) {
        self.profileRepository = profileRepository
    }

    // MARK: - Explicit preference mutations

    func recordLike(_ activity: Activity, for contact: TrackedContact) {
        let profile = profileRepository.fetchOrCreate(for: contact.id)
        profile.addLike(activity)
        try? profileRepository.save()
    }

    func recordDislike(_ activity: Activity, for contact: TrackedContact) {
        let profile = profileRepository.fetchOrCreate(for: contact.id)
        profile.addDislike(activity)
        try? profileRepository.save()
    }

    func removeSentiment(for activity: Activity, contact: TrackedContact) {
        let profile = profileRepository.fetchOrCreate(for: contact.id)
        profile.removeSentiment(for: activity)
        try? profileRepository.save()
    }

    func updateNotes(_ notes: String, for contact: TrackedContact) {
        let profile = profileRepository.fetchOrCreate(for: contact.id)
        profile.notes = notes
        profile.lastUpdated = .now
        try? profileRepository.save()
    }

    // MARK: - Inference confirmation

    func confirmInference(for contact: TrackedContact) {
        let profile = profileRepository.fetchOrCreate(for: contact.id)
        guard let pending = profile.pendingInference else { return }
        profile.addLike(pending)
        profile.pendingInferenceRaw = nil
        try? profileRepository.save()
    }

    func dismissInference(for contact: TrackedContact) {
        let profile = profileRepository.fetchOrCreate(for: contact.id)
        profile.pendingInferenceRaw = nil
        profile.lastUpdated = .now
        try? profileRepository.save()
    }

    // MARK: - Pattern inference

    /// Analyzes hangout history for a dominant activity. If found, sets a pending
    /// inference on the profile awaiting user confirmation. No-ops if the profile
    /// already has explicit preferences or an existing pending inference.
    func inferPatternIfNeeded(for contact: TrackedContact, from hangouts: [ScheduledHangout]) {
        let profile = profileRepository.fetchOrCreate(for: contact.id)
        guard profile.pendingInferenceRaw == nil, profile.likedActivities.isEmpty else { return }

        let contactHangouts = hangouts.filter { $0.contact?.id == contact.id && $0.startDate < .now }
        guard contactHangouts.count >= 3 else { return }

        var activityCounts: [Activity: Int] = [:]
        for hangout in contactHangouts {
            guard let activity = hangout.resolvedActivity else { continue }
            activityCounts[activity, default: 0] += 1
        }

        let totalTagged = activityCounts.values.reduce(0, +)
        guard totalTagged > 0,
              let (dominant, count) = activityCounts.max(by: { $0.value < $1.value }),
              Double(count) / Double(totalTagged) >= 0.5
        else { return }

        profile.pendingInferenceRaw = dominant.rawValue
        profile.lastUpdated = .now
        try? profileRepository.save()
    }

    // MARK: - Activity ranking

    /// Returns a scored, weighted-random Activity for a suggestion to this contact.
    ///
    /// Scoring per candidate:
    ///   +3 liked by user
    ///   +2 not done together in last 5 hangouts (novelty)
    ///   -1 appears more than twice in last 5 hangouts (overused)
    ///   excluded if in disliked list
    func rankedActivity(for contact: TrackedContact, recentHangouts: [ScheduledHangout]) -> Activity? {
        let profile = profileRepository.fetch(for: contact.id)
        let liked = profile?.likedActivities ?? []
        let disliked = profile?.dislikedActivities ?? []

        let recent5 = recentHangouts
            .filter { $0.contact?.id == contact.id && $0.startDate < .now }
            .sorted { $0.startDate > $1.startDate }
            .prefix(5)
        let recentActivities = recent5.compactMap { $0.resolvedActivity }
        var recentCounts: [Activity: Int] = [:]
        for a in recentActivities { recentCounts[a, default: 0] += 1 }

        var scored: [(activity: Activity, weight: Int)] = []
        for activity in Activity.allCases {
            guard !disliked.contains(activity) else { continue }
            var score = 0
            if liked.contains(activity) { score += 3 }
            if !recentActivities.contains(activity) { score += 2 }
            if (recentCounts[activity] ?? 0) > 2 { score -= 1 }
            scored.append((activity, max(score + 1, 1))) // +1 ensures minimum weight > 0
        }

        guard !scored.isEmpty else { return Activity.allCases.randomElement() }

        let totalWeight = scored.reduce(0) { $0 + $1.weight }
        var roll = Int.random(in: 0..<max(totalWeight, 1))
        for pair in scored {
            if roll < pair.weight { return pair.activity }
            roll -= pair.weight
        }
        return scored.first?.activity
    }

    // MARK: - Profile access

    func profile(for contact: TrackedContact) -> ContactProfile {
        profileRepository.fetchOrCreate(for: contact.id)
    }
}
