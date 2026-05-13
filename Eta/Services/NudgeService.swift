import Foundation
import UserNotifications

extension Notification.Name {
    static let hangoutScheduled = Notification.Name("me.Eta.hangoutScheduled")
}

/// Schedules friend-driven nudge notifications.
///
/// Two orthogonal flags — force (debug) and llmMode (API key present) — produce four modes:
///
/// |              | Debug (force=true)                                      | Production (force=false)                                |
/// |--------------|---------------------------------------------------------|---------------------------------------------------------|
/// | LLM mode     | Activity: LLM free-form  · Body: LLM                    | Activity: LLM free-form  · Body: LLM                   |
/// |              | hasPhotos: any friend    · Banner: any friend            | hasPhotos: any friend    · Banner: any friend            |
/// | Enum mode    | Activity: photo-biased enum · Body: template            | Activity: random enum    · Body: template               |
/// |              | hasPhotos: any friend    · Banner: friend+act→friend→act | hasPhotos: activity-specific · Banner: friend+act→friend→act |
///
/// Activity selection: only Debug+Enum uses photo-biased enum directly; all other cases go
/// through runner — which returns a free-form LLM phrase with a key, or a random enum rawValue
/// without — so the no-key fallback in GitHubModelsLLMRunner is the single source of random enum.
/// hasPhotos / Banner photo both branch on llmMode (not force): llmMode → any friend; else → enum lookup.
final class NudgeService {
    private static let scheduledNudgeID = "me.Eta.nudge.scheduled"

    private let relationshipService: RelationshipService
    private let photoRepository: ActivityPhotoRepository
    private let runner: any LLMRunner

    private var llmMode: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "LLM_API_KEY") as? String).map { !$0.isEmpty } ?? false
    }

    init(
        relationshipService: RelationshipService,
        photoRepository: ActivityPhotoRepository,
        runner: any LLMRunner
    ) {
        self.relationshipService = relationshipService
        self.photoRepository = photoRepository
        self.runner = runner

        NotificationCenter.default.addObserver(
            forName: .hangoutScheduled,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.scheduleNudge() }
        }
    }

    // MARK: - Public

    func scheduleNudge(force: Bool = false) async {
        let (content, identifier, trigger) = await buildNudge(force: force)
        guard let content, let trigger else { return }

        if !force {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [Self.scheduledNudgeID])
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Private

    private func buildNudge(force: Bool) async -> (UNMutableNotificationContent?, String, UNNotificationTrigger?) {
        let healthScores = await relationshipService.computeHealth()
        let best = healthScores.max(by: { $0.score < $1.score })

        var activityDescription: String
        var fallbackActivity: Activity
        let contactID: UUID?
        let friendName: String?
        let hasPhotos: Bool

        if let health = best {
            let contact = health.contact
            contactID = contact.id
            friendName = contact.givenName.isEmpty ? contact.name : contact.givenName
            let friendPhotos = photoRepository.photos(forContactID: contact.id)

            // Activity selection:
            // Enum Debug: photo-biased cascade — friend+activity → friend (any) → repo → random.
            // All other cases (LLM debug/production, Enum Production): runner — free-form with key, random rawValue without.
            if force && !llmMode {
                // compactMap covers friend+activity and friend-any-photo: photos always carry valid rawValues.
                let friendActivities = friendPhotos.compactMap { Activity(rawValue: $0.activityRawValue) }
                let repoActivities = Activity.allCases.filter { !photoRepository.photos(for: $0).isEmpty }
                fallbackActivity = friendActivities.randomElement()
                    ?? repoActivities.randomElement()
                    ?? Activity.allCases.randomElement()
                    ?? .walk
                activityDescription = fallbackActivity.rawValue
            } else {
                activityDescription = await suggestActivity(for: health)
                fallbackActivity = Activity(rawValue: activityDescription) ?? .walk
            }

            // hasPhotos drives body text ("great time" vs "it's been a while").
            // LLM mode or debug: any friend photo (activity is free-form or we want demo coverage).
            // Production + Enum: only true when friend has a photo for this specific activity.
            if llmMode || force {
                hasPhotos = !friendPhotos.isEmpty
            } else {
                hasPhotos = friendPhotos.contains { $0.activityRawValue == fallbackActivity.rawValue }
            }
        } else {
            contactID = nil
            friendName = nil
            hasPhotos = false
            if force {
                // Debug with no friends: show the most-photographed activity.
                fallbackActivity = Activity.allCases.max {
                    photoRepository.photos(for: $0).count < photoRepository.photos(for: $1).count
                } ?? .walk
                activityDescription = fallbackActivity.rawValue
            } else {
                // No friend context — runner with a generic prompt (same code path).
                activityDescription = await suggestActivity(for: nil)
                fallbackActivity = Activity(rawValue: activityDescription) ?? .walk
            }
        }

        // Banner photo:
        // LLM mode: any friend photo (activity is free-form, matching is meaningless).
        // Enum mode: friend photo for this activity → any friend photo → activity-scoped fallback.
        let photoData: Data?
        if let id = contactID {
            if llmMode {
                photoData = photoRepository.photos(forContactID: id).first?.imageData
            } else {
                photoData = photoRepository.photos(forContactID: id)
                    .first { $0.activityRawValue == fallbackActivity.rawValue }?.imageData
                    ?? photoRepository.photos(forContactID: id).first?.imageData
                    ?? photoRepository.photos(for: fallbackActivity).first?.imageData
            }
        } else {
            photoData = photoRepository.photos(for: fallbackActivity).first?.imageData
        }

        let title = friendName.map { "Time to catch up with \($0)" } ?? activityDescription
        let body = await nudgeBody(
            activityDescription: activityDescription,
            fallbackActivity: fallbackActivity,
            friendName: friendName,
            hasPhotos: hasPhotos
        )

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let attachment = makeAttachment(from: photoData) {
            content.attachments = [attachment]
        }
        content.userInfo = {
            var info: [String: String] = [
                "notificationType": "nudge",
                "activityRawValue": activityDescription
            ]
            if let id = contactID { info["contactID"] = id.uuidString }
            if let name = friendName { info["friendName"] = name }
            return info
        }()

        let identifier = force ? "nudge-debug-\(UUID().uuidString)" : Self.scheduledNudgeID
        let trigger: UNNotificationTrigger = force
            ? UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            : UNCalendarNotificationTrigger(dateMatching: next9am(), repeats: false)

        return (content, identifier, trigger)
    }

    /// Asks the runner to suggest an activity phrase using the same prompt as LLMActivityStrategy.
    /// On any runner error (no API key, network failure, etc.) falls back to a random Activity rawValue.
    /// Pass nil health for the no-friend case (generic prompt).
    private func suggestActivity(for health: RelationshipHealth?) async -> String {
        let system = """
        You are a helpful assistant that suggests activities for friends to do together. \
        Suggest a single short activity phrase (2–5 words, imperative form, e.g. "Grab coffee", "Go for a walk"). \
        Reply with ONLY the activity phrase — no punctuation, no explanation, nothing else.
        """
        let userPrompt: String
        if let health {
            let name = health.contact.givenName.isEmpty ? health.contact.name : health.contact.givenName
            let context = health.daysSinceLastHangout.map { "They haven't seen \(name) in \($0) days." }
                ?? "They haven't hung out with \(name) yet."
            userPrompt = "Suggest an activity for the user to do with \(name). \(context)"
        } else {
            userPrompt = "Suggest a fun activity for two friends to do together."
        }

        let raw = (try? await runner.generate(systemPrompt: system, userPrompt: userPrompt)) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (Activity.allCases.randomElement()?.rawValue ?? Activity.walk.rawValue) : trimmed
    }

    private func next9am() -> DateComponents {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = 9
        components.minute = 0
        let today9am = Calendar.current.date(from: components)!
        let fireDate = today9am > .now
            ? today9am
            : Calendar.current.date(byAdding: .day, value: 1, to: today9am)!
        return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
    }

    private func makeAttachment(from data: Data?) -> UNNotificationAttachment? {
        guard let data else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".jpg")
        guard (try? data.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: UUID().uuidString, url: url)
    }

    private func nudgeBody(
        activityDescription: String,
        fallbackActivity: Activity,
        friendName: String?,
        hasPhotos: Bool
    ) async -> String {
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "LLM_API_KEY") as? String
        if let apiKey, !apiKey.isEmpty {
            let system = """
            You write short, warm push notification body text for a friendship app. \
            The notification is sent TO the app user to encourage them to reach out to a friend — \
            it is NOT a message to the friend. \
            Write in second person ("you", "your"). \
            Reply with ONLY the body — one sentence, no trailing punctuation.
            """
            let user: String
            if let name = friendName {
                user = hasPhotos
                    ? "Encourage the user to reach out to \(name) and \(activityDescription.lowercased()) together, referencing a past shared memory"
                    : "Encourage the user to reach out to \(name) and \(activityDescription.lowercased()) to catch up"
            } else {
                user = "Encourage the user to reach out to a friend and \(activityDescription.lowercased()) together"
            }
            let raw = try? await runner.generate(systemPrompt: system, userPrompt: user)
            let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let isActivityName = Activity(rawValue: trimmed) != nil
            if !trimmed.isEmpty, !isActivityName { return trimmed }
        }
        return templateBody(activity: fallbackActivity, friendName: friendName, hasPhotos: hasPhotos)
    }

    private func templateBody(activity: Activity, friendName: String?, hasPhotos: Bool) -> String {
        if let name = friendName {
            return hasPhotos
                ? "You had a great time with \(name) — how about doing it again?"
                : "It's been a while since you caught up with \(name)"
        }
        switch activity {
        case .walk:         return "Why not invite a friend for a walk today?"
        case .coffee:       return "How about reaching out to grab coffee with someone?"
        case .groceryRun:   return "Make the errand more fun — invite a friend along"
        case .lunch:        return "How about getting lunch with someone this week?"
        case .workout:      return "Why not work out with a friend today?"
        case .studySession: return "How about setting up a study session with a friend?"
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
