import Foundation

/// Generates and caches the daily PersonalRelationshipInsight.
///
/// Runs rule-based logic over hangout history and relationship health scores.
/// One insight is generated per 12-hour window and cached in the repository.
final class InsightGenerationService {
    private let insightRepository: PersonalRelationshipInsightRepository
    private let hangoutRepository: ScheduledHangoutRepository
    private let contactRepository: ContactRepository
    private let profileRepository: ContactProfileRepository

    /// UserDefaults key tracking consecutive dismissals per InsightType.
    private static let dismissalKey = "insight_dismissal_counts"
    /// Number of consecutive dismissals of one type before suppressing for two weeks.
    private static let suppressionThreshold = 3
    private static let suppressionDuration: TimeInterval = 14 * 24 * 3600

    init(
        insightRepository: PersonalRelationshipInsightRepository,
        hangoutRepository: ScheduledHangoutRepository,
        contactRepository: ContactRepository,
        profileRepository: ContactProfileRepository
    ) {
        self.insightRepository = insightRepository
        self.hangoutRepository = hangoutRepository
        self.contactRepository = contactRepository
        self.profileRepository = profileRepository
    }

    // MARK: - Public

    func generateDailyInsight(
        healthScores: [RelationshipHealth],
        goals: [Goal]
    ) async -> PersonalRelationshipInsight? {
        if let cached = try? insightRepository.fetchTodaysInsight() {
            return cached
        }
        let hangouts = (try? hangoutRepository.fetchAll()) ?? []
        let contacts = (try? contactRepository.fetchAll()) ?? []
        let candidates = buildCandidates(
            healthScores: healthScores,
            goals: goals,
            hangouts: hangouts,
            contacts: contacts
        )
        guard let best = pickBest(from: candidates, goals: goals) else { return nil }
        try? insightRepository.add(best)
        return best
    }

    func dismiss(_ insight: PersonalRelationshipInsight) {
        try? insightRepository.dismiss(insight)
        incrementDismissal(for: insight.type)
    }

    func snooze(_ insight: PersonalRelationshipInsight) {
        // Snoozing just dismisses — user will see a fresh one after the next 12-hour window.
        try? insightRepository.dismiss(insight)
    }

    // MARK: - Candidate generation

    private func buildCandidates(
        healthScores: [RelationshipHealth],
        goals: [Goal],
        hangouts: [ScheduledHangout],
        contacts: [TrackedContact]
    ) -> [PersonalRelationshipInsight] {
        var candidates: [PersonalRelationshipInsight] = []

        candidates += reflectionCandidates(from: hangouts, contacts: contacts)
        candidates += driftCandidates(from: healthScores, hangouts: hangouts)
        candidates += networkCandidates(from: hangouts, contacts: contacts)
        candidates += patternConfirmationCandidates(from: contacts)
        candidates += noveltyNudgeCandidates(from: contacts, hangouts: hangouts)

        return candidates
    }

    // Reflection: recent confirmed hangout with no feedback yet.
    private func reflectionCandidates(
        from hangouts: [ScheduledHangout],
        contacts: [TrackedContact]
    ) -> [PersonalRelationshipInsight] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return hangouts
            .filter { $0.startDate >= cutoff && $0.startDate <= .now && $0.inviteeResponse == .confirmed }
            .compactMap { hangout -> PersonalRelationshipInsight? in
                guard let contact = hangout.contact else { return nil }
                let activity = hangout.resolvedActivity?.rawValue ?? "hangout"
                return PersonalRelationshipInsight(
                    type: .reflection,
                    friendID: contact.id,
                    headline: "How was \(activity.lowercased()) with \(contact.givenName)?",
                    primaryAction: .reflect
                )
            }
    }

    // Drift: contact not seen in longer than 1.5× their inferred cadence.
    private func driftCandidates(
        from healthScores: [RelationshipHealth],
        hangouts: [ScheduledHangout]
    ) -> [PersonalRelationshipInsight] {
        // Build last-seen lookup from ScheduledHangout history.
        var lastSeen: [UUID: Date] = [:]
        var hangoutCountPer: [UUID: Int] = [:]
        for h in hangouts where h.startDate < .now {
            guard let cid = h.contact?.id else { continue }
            if let existing = lastSeen[cid] {
                if h.startDate > existing { lastSeen[cid] = h.startDate }
            } else {
                lastSeen[cid] = h.startDate
            }
            hangoutCountPer[cid, default: 0] += 1
        }

        return healthScores.compactMap { health -> PersonalRelationshipInsight? in
            let contact = health.contact
            guard contact.isActive else { return nil }
            guard let last = lastSeen[contact.id] else {
                // Never hung out — lower priority drift
                let days = Calendar.current.dateComponents([.day], from: contact.addedAt, to: .now).day ?? 0
                guard days > 14 else { return nil }
                return PersonalRelationshipInsight(
                    type: .drift,
                    friendID: contact.id,
                    headline: "You haven't hung out with \(contact.givenName) yet — want to plan something?",
                    primaryAction: .planActivity
                )
            }

            let daysSince = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
            let count = hangoutCountPer[contact.id] ?? 0
            // Infer typical cadence: total window ÷ count, default 30 days
            let inferredCadenceDays = count > 1 ? max(7, 90 / count) : 30
            let threshold = Int(Double(inferredCadenceDays) * 1.5)
            guard daysSince >= threshold else { return nil }

            let weeks = daysSince / 7
            let timeStr = weeks >= 2 ? "\(weeks) weeks" : "\(daysSince) days"
            return PersonalRelationshipInsight(
                type: .drift,
                friendID: contact.id,
                headline: "It's been \(timeStr) since you hung out with \(contact.givenName).",
                primaryAction: .planActivity
            )
        }
    }

    // Network: if >65% of recent hangouts are concentrated in 2 contacts.
    private func networkCandidates(
        from hangouts: [ScheduledHangout],
        contacts: [TrackedContact]
    ) -> [PersonalRelationshipInsight] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let recent = hangouts.filter { $0.startDate >= cutoff && $0.startDate <= .now }
        guard recent.count >= 4 else { return [] }

        var countPer: [UUID: Int] = [:]
        for h in recent {
            guard let cid = h.contact?.id else { continue }
            countPer[cid, default: 0] += 1
        }
        let top2 = countPer.values.sorted(by: >).prefix(2)
        let top2Total = top2.reduce(0, +)
        guard Double(top2Total) / Double(recent.count) > 0.65 else { return [] }

        return [PersonalRelationshipInsight(
            type: .network,
            headline: "Most of your recent hangouts have been with the same people. Want to reach out to someone else?",
            primaryAction: .planActivity
        )]
    }

    // Pattern confirmation: contact profile has a pending inference waiting for user sign-off.
    private func patternConfirmationCandidates(from contacts: [TrackedContact]) -> [PersonalRelationshipInsight] {
        contacts.compactMap { contact -> PersonalRelationshipInsight? in
            guard let profile = profileRepository.fetch(for: contact.id),
                  let pending = profile.pendingInference
            else { return nil }
            return PersonalRelationshipInsight(
                type: .pattern,
                friendID: contact.id,
                headline: "Looks like you and \(contact.givenName) usually \(pending.rawValue.lowercased()) — add as a preference?",
                primaryAction: .reflect
            )
        }
    }

    // Novelty nudge: contact has an established preference but recent hangouts are low-variety.
    private func noveltyNudgeCandidates(
        from contacts: [TrackedContact],
        hangouts: [ScheduledHangout]
    ) -> [PersonalRelationshipInsight] {
        contacts.compactMap { contact -> PersonalRelationshipInsight? in
            guard let profile = profileRepository.fetch(for: contact.id),
                  !profile.likedActivities.isEmpty
            else { return nil }

            let recent = hangouts
                .filter { $0.contact?.id == contact.id && $0.startDate < .now }
                .sorted { $0.startDate > $1.startDate }
                .prefix(5)
            guard recent.count >= 3 else { return nil }

            var counts: [Activity: Int] = [:]
            for h in recent { if let a = h.resolvedActivity { counts[a, default: 0] += 1 } }
            guard let (dominant, count) = counts.max(by: { $0.value < $1.value }),
                  Double(count) / Double(recent.count) >= 0.6
            else { return nil }

            return PersonalRelationshipInsight(
                type: .pattern,
                friendID: contact.id,
                headline: "You and \(contact.givenName) have mostly been \(dominant.rawValue.lowercased()) — want to try something new?",
                primaryAction: .planActivity
            )
        }
    }

    // MARK: - Ranking

    private func pickBest(
        from candidates: [PersonalRelationshipInsight],
        goals: [Goal]
    ) -> PersonalRelationshipInsight? {
        let suppressed = suppressedTypes()
        let eligible = candidates.filter { !suppressed.contains($0.type) }
        guard !eligible.isEmpty else { return candidates.first }

        let goalFriendIDs = Set(goals.flatMap { $0.friendIDs })

        return eligible.max { a, b in
            score(a, goalFriendIDs: goalFriendIDs) < score(b, goalFriendIDs: goalFriendIDs)
        }
    }

    private func score(_ insight: PersonalRelationshipInsight, goalFriendIDs: Set<UUID>) -> Int {
        var s = 0
        switch insight.type {
        case .reflection: s += 30
        case .drift:      s += 20
        case .network:    s += 10
        default:          s += 5
        }
        if let fid = insight.friendID, goalFriendIDs.contains(fid) { s += 10 }
        return s
    }

    // MARK: - Dismissal suppression

    private func suppressedTypes() -> Set<InsightType> {
        guard let data = UserDefaults.standard.data(forKey: Self.dismissalKey),
              let dict = try? JSONDecoder().decode([String: DismissalRecord].self, from: data)
        else { return [] }

        let now = Date()
        return Set(dict.compactMap { (key, record) -> InsightType? in
            guard let type = InsightType(rawValue: key) else { return nil }
            guard record.count >= Self.suppressionThreshold else { return nil }
            guard let suppressedUntil = record.suppressedUntil, now < suppressedUntil else { return nil }
            return type
        })
    }

    private func incrementDismissal(for type: InsightType) {
        var dict: [String: DismissalRecord]
        if let data = UserDefaults.standard.data(forKey: Self.dismissalKey),
           let decoded = try? JSONDecoder().decode([String: DismissalRecord].self, from: data) {
            dict = decoded
        } else {
            dict = [:]
        }

        var record = dict[type.rawValue] ?? DismissalRecord(count: 0, suppressedUntil: nil)
        record.count += 1
        if record.count >= Self.suppressionThreshold {
            record.suppressedUntil = Date().addingTimeInterval(Self.suppressionDuration)
        }
        dict[type.rawValue] = record

        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: Self.dismissalKey)
        }
    }

    private struct DismissalRecord: Codable {
        var count: Int
        var suppressedUntil: Date?
    }
}
