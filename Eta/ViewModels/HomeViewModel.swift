import Foundation
import CoreLocation

struct FriendSpotlightItem: Identifiable {
    var id: UUID { contact.id }
    let contact: TrackedContact
    let contextLine: String
    let health: RelationshipHealth
}

struct RecentWinItem: Identifiable {
    var id: UUID { hangout.id }
    let hangout: ScheduledHangout
    let contact: TrackedContact
    let contextLine: String
}

@MainActor
@Observable
final class HomeViewModel {
    private(set) var greeting: String = ""
    private(set) var weekSummary: String = ""
    private(set) var currentInsight: PersonalRelationshipInsight?
    private(set) var activeGoals: [Goal] = []
    private(set) var friendSpotlights: [FriendSpotlightItem] = []
    private(set) var recentWins: [RecentWinItem] = []
    private(set) var contacts: [TrackedContact] = []
    private(set) var isLoading: Bool = false
    private(set) var profileVersion: Int = 0

    private var allHangouts: [ScheduledHangout] = []

    private let goalRepository: GoalRepository
    private let insightGenerationService: InsightGenerationService
    private let goalTrackingService: GoalTrackingService
    private let contactRepository: ContactRepository
    private let hangoutRepository: ScheduledHangoutRepository
    let formatter: ContactFormatter
    private let relationshipService: RelationshipService
    private let contactProfileService: ContactProfileService
    private let preferencesService: PreferencesService

    var checkInTemplate: String? { preferencesService.preferences.checkInTemplate }
    var hasSetCheckInTemplate: Bool { preferencesService.preferences.hasSetCheckInTemplate }

    init(
        goalRepository: GoalRepository,
        insightGenerationService: InsightGenerationService,
        goalTrackingService: GoalTrackingService,
        contactRepository: ContactRepository,
        hangoutRepository: ScheduledHangoutRepository,
        formatter: ContactFormatter,
        relationshipService: RelationshipService,
        contactProfileService: ContactProfileService,
        preferencesService: PreferencesService
    ) {
        self.goalRepository = goalRepository
        self.insightGenerationService = insightGenerationService
        self.goalTrackingService = goalTrackingService
        self.contactRepository = contactRepository
        self.hangoutRepository = hangoutRepository
        self.formatter = formatter
        self.relationshipService = relationshipService
        self.contactProfileService = contactProfileService
        self.preferencesService = preferencesService
    }

    // MARK: - Refresh

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        goalTrackingService.updateAllGoals()

        contacts = (try? contactRepository.fetchAll()) ?? []
        allHangouts = (try? hangoutRepository.fetchAll()) ?? []
        activeGoals = (try? goalRepository.fetchActive()) ?? []

        for contact in contacts {
            contactProfileService.inferPatternIfNeeded(for: contact, from: allHangouts)
        }

        // First pass: populate spotlights immediately from SwiftData without waiting for calendar.
        friendSpotlights = computeSpotlights(healthScores: [])
        recentWins = computeRecentWins()
        greeting = computeGreeting()
        weekSummary = computeWeekSummary()

        let healthScores = await relationshipService.computeHealth()

        async let insightTask = insightGenerationService.generateDailyInsight(
            healthScores: healthScores,
            goals: activeGoals
        )

        currentInsight = await insightTask
        // Second pass: refresh with calendar-enhanced health data.
        friendSpotlights = computeSpotlights(healthScores: healthScores)
    }

    // MARK: - Insight actions

    func dismissInsight() {
        guard let insight = currentInsight else { return }
        insightGenerationService.dismiss(insight)
        currentInsight = nil
    }

    func snoozeInsight() {
        guard let insight = currentInsight else { return }
        insightGenerationService.snooze(insight)
        currentInsight = nil
    }

    // MARK: - Goal actions

    func createGoal(_ goal: Goal) {
        try? goalRepository.add(goal)
        activeGoals = (try? goalRepository.fetchActive()) ?? []
    }

    func deleteGoal(_ goal: Goal) {
        try? goalRepository.remove(goal)
        activeGoals = (try? goalRepository.fetchActive()) ?? []
    }

    func pauseGoal(_ goal: Goal) {
        goal.isPaused = true
        try? goalRepository.save()
        activeGoals = (try? goalRepository.fetchActive()) ?? []
    }

    func saveGoalEdits() {
        try? goalRepository.save()
        activeGoals = (try? goalRepository.fetchActive()) ?? []
    }

    // MARK: - Display helpers

    func displayName(for contact: TrackedContact) -> String {
        formatter.displayName(for: contact)
    }

    func goals(for contact: TrackedContact) -> [Goal] {
        let all = activeGoals.isEmpty ? ((try? goalRepository.fetchAll()) ?? []) : activeGoals
        return all.filter { $0.friendIDs.contains(contact.id) }
    }

    func pastHangouts(for contact: TrackedContact) -> [ScheduledHangout] {
        let all = allHangouts.isEmpty ? ((try? hangoutRepository.fetchAll()) ?? []) : allHangouts
        return all
            .filter { $0.contact?.id == contact.id && $0.startDate <= .now }
            .sorted { $0.startDate > $1.startDate }
    }

    func upcomingHangouts(for contact: TrackedContact) -> [ScheduledHangout] {
        let all = allHangouts.isEmpty ? ((try? hangoutRepository.fetchAll()) ?? []) : allHangouts
        return all
            .filter { $0.contact?.id == contact.id && $0.startDate > .now && $0.inviteeResponse != .declined }
            .sorted { $0.startDate < $1.startDate }
    }

    func allGoals() -> [Goal] {
        (try? goalRepository.fetchAll()) ?? []
    }

    // MARK: - Contact profile

    func contactProfile(for contact: TrackedContact) -> ContactProfile {
        contactProfileService.profile(for: contact)
    }

    func recordLike(_ activity: Activity, for contact: TrackedContact) {
        contactProfileService.recordLike(activity, for: contact)
        profileVersion += 1
    }

    func recordDislike(_ activity: Activity, for contact: TrackedContact) {
        contactProfileService.recordDislike(activity, for: contact)
        profileVersion += 1
    }

    func confirmPattern(for contact: TrackedContact) {
        contactProfileService.confirmInference(for: contact)
        profileVersion += 1
    }

    func dismissPattern(for contact: TrackedContact) {
        contactProfileService.dismissInference(for: contact)
        profileVersion += 1
    }

    func removeSentiment(for activity: Activity, contact: TrackedContact) {
        contactProfileService.removeSentiment(for: activity, contact: contact)
        profileVersion += 1
    }

    func updateNotes(_ notes: String, for contact: TrackedContact) {
        contactProfileService.updateNotes(notes, for: contact)
        profileVersion += 1
    }

    func updateCheckInTemplate(_ template: String) {
        preferencesService.updateCheckInTemplate(template)
    }

    func markCheckInTemplateSet() {
        preferencesService.markCheckInTemplateSet()
    }

    func updateCity(_ city: String?, for contact: TrackedContact) {
        contact.city = city
        recomputeIsRemote(for: contact)
        try? contactRepository.save()
    }

    func updateUserCity(_ city: String?) {
        preferencesService.updateUserCity(city)
        recomputeAllIsRemote()
    }

    func recomputeAllIsRemote() {
        for contact in contacts {
            recomputeIsRemote(for: contact)
        }
        try? contactRepository.save()
    }

    private func recomputeIsRemote(for contact: TrackedContact) {
        let prefs = preferencesService.preferences
        if let uLat = prefs.userLatitude, let uLon = prefs.userLongitude,
           let cLat = contact.cityLatitude, let cLon = contact.cityLongitude {
            let userLoc = CLLocation(latitude: uLat, longitude: uLon)
            let contactLoc = CLLocation(latitude: cLat, longitude: cLon)
            contact.isRemote = userLoc.distance(from: contactLoc) > 80_000 // 80 km
            return
        }
        let userCity = prefs.userCity?.lowercased()
        let contactCity = contact.city?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let userCity, !userCity.isEmpty,
              let contactCity, !contactCity.isEmpty else { return }
        contact.isRemote = userCity != contactCity
    }

    func updateCityCoordinates(_ latitude: Double, _ longitude: Double, for contact: TrackedContact) {
        contact.cityLatitude = latitude
        contact.cityLongitude = longitude
        recomputeIsRemote(for: contact)
        try? contactRepository.save()
    }

    func updateUserCoordinates(_ latitude: Double, _ longitude: Double) {
        preferencesService.updateUserCoordinates(latitude, longitude)
        recomputeAllIsRemote()
    }

    func geocodeMissingCities() async {
        let geocoder = CLGeocoder()
        for contact in contacts where contact.city != nil && contact.cityLatitude == nil {
            guard let city = contact.city else { continue }
            if let placemarks = try? await geocoder.geocodeAddressString(city),
               let loc = placemarks.first?.location {
                contact.cityLatitude = loc.coordinate.latitude
                contact.cityLongitude = loc.coordinate.longitude
            }
        }
        try? contactRepository.save()
        let prefs = preferencesService.preferences
        if let city = prefs.userCity, prefs.userLatitude == nil {
            if let placemarks = try? await geocoder.geocodeAddressString(city),
               let loc = placemarks.first?.location {
                preferencesService.updateUserCoordinates(loc.coordinate.latitude, loc.coordinate.longitude)
            }
        }
        recomputeAllIsRemote()
    }

    func updateTags(_ tags: [ContactTag], for contact: TrackedContact) {
        contact.contextTags = tags
        try? contactRepository.save()
    }

    var existingCustomLabels: [TagSubcategory: [String]] {
        var result: [TagSubcategory: [String]] = [:]
        for contact in contacts {
            for tag in contact.contextTags {
                guard let label = tag.customLabel, !label.isEmpty else { continue }
                result[tag.subcategory, default: []].append(label)
            }
        }
        for key in result.keys { result[key] = Array(Set(result[key]!)).sorted() }
        return result
    }

    func deleteHangout(_ hangout: ScheduledHangout) {
        try? hangoutRepository.remove(hangout)
        allHangouts = (try? hangoutRepository.fetchAll()) ?? []
    }

    func logPastHangout(contact: TrackedContact, activity: String, date: Date) {
        let interval = DateInterval(start: date, duration: 3600)
        let hangout = ScheduledHangout(contact: contact, activity: activity, selectedTime: interval)
        hangout.inviteeResponse = .confirmed
        try? hangoutRepository.add(hangout)
        allHangouts = (try? hangoutRepository.fetchAll()) ?? []
    }

    // MARK: - Private computation

    private func computeGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "Good morning."
        case 12..<17: return "Good afternoon."
        case 17..<21: return "Good evening."
        default:      return "Hey there."
        }
    }

    private func computeWeekSummary() -> String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let recentCount = allHangouts.filter {
            $0.startDate >= cutoff && $0.startDate <= .now && $0.inviteeResponse == .confirmed
        }.count

        if recentCount == 0 { return "Let's plan something this week." }
        if recentCount == 1 { return "You saw 1 friend this week." }
        return "You've seen \(recentCount) friends this week."
    }

    private func computeSpotlights(healthScores: [RelationshipHealth]) -> [FriendSpotlightItem] {
        var result: [FriendSpotlightItem] = []
        var usedIDs: Set<UUID> = []

        let lastSeenMap = buildLastSeenMap()
        let healthByID = Dictionary(uniqueKeysWithValues: healthScores.map { ($0.contact.id, $0) })

        // Slot 1: friend with an active at-risk or behind goal
        let urgentGoal = activeGoals.first { $0.status == .atRisk || $0.status == .behind }
        if let goal = urgentGoal, let friendID = goal.friendIDs.first,
           let contact = contacts.first(where: { $0.id == friendID }),
           let health = healthByID[contact.id] {
            let days = goal.daysRemaining
            let context = "Goal at risk — \(days) day\(days == 1 ? "" : "s") left"
            result.append(FriendSpotlightItem(contact: contact, contextLine: context, health: health))
            usedIDs.insert(contact.id)
        }

        // Slots 2 & 3: most drifting contacts (longest since last hangout)
        let sorted = contacts
            .filter { $0.isActive && !usedIDs.contains($0.id) }
            .sorted { a, b in
                let aDate = lastSeenMap[a.id] ?? .distantPast
                let bDate = lastSeenMap[b.id] ?? .distantPast
                return aDate < bDate
            }

        for contact in sorted.prefix(3 - result.count) {
            let health = healthByID[contact.id] ?? RelationshipHealth(
                contact: contact,
                lastHangoutDate: nil,
                lastHangoutTitle: nil,
                hangoutCount: 0,
                score: 0,
                upcomingHangout: nil
            )
            let context = driftContext(for: contact, lastSeen: lastSeenMap[contact.id])
            result.append(FriendSpotlightItem(contact: contact, contextLine: context, health: health))
            usedIDs.insert(contact.id)
        }

        return result
    }

    private func buildLastSeenMap() -> [UUID: Date] {
        var map: [UUID: Date] = [:]
        for hangout in allHangouts where hangout.startDate < .now {
            guard let cid = hangout.contact?.id else { continue }
            if let existing = map[cid] {
                if hangout.startDate > existing { map[cid] = hangout.startDate }
            } else {
                map[cid] = hangout.startDate
            }
        }
        return map
    }

    private func driftContext(for contact: TrackedContact, lastSeen: Date?) -> String {
        guard let last = lastSeen else {
            return "You haven't hung out yet — time to plan something?"
        }
        let days = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
        if days > 30 { return "You used to see them more — last hung out \(days) days ago" }
        if days == 1 { return "Last hung out yesterday" }
        return "Last hung out \(days) days ago"
    }

    private func computeRecentWins() -> [RecentWinItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return allHangouts
            .filter { $0.startDate >= cutoff && $0.startDate <= .now && $0.inviteeResponse == .confirmed }
            .compactMap { hangout -> RecentWinItem? in
                guard let contact = hangout.contact else { return nil }
                let activity = hangout.resolvedActivity?.rawValue ?? "Hangout"
                let df = DateFormatter()
                df.dateFormat = "EEEE"
                let dayName = df.string(from: hangout.startDate)
                let context = "\(activity) with \(contact.givenName) \(dayName). How was it?"
                return RecentWinItem(hangout: hangout, contact: contact, contextLine: context)
            }
            .sorted { $0.hangout.startDate > $1.hangout.startDate }
    }
}
