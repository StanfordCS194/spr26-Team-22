import Foundation

/// Computes RelationshipHealth for every tracked contact by fanning out
/// to all registered ImplicitDataProviders and correlating their events.
final class RelationshipService {
    private let providers: [any ImplicitDataProvider]
    private let repository: ContactRepository
    private let hangoutRepository: ScheduledHangoutRepository
    private let preferencesService: PreferencesService
    private var analyticsService: AnalyticsService?
    private var hasRequestedCalendarPermission = false

    init(
        providers: [any ImplicitDataProvider],
        repository: ContactRepository,
        hangoutRepository: ScheduledHangoutRepository,
        preferencesService: PreferencesService
    ) {
        self.providers = providers
        self.repository = repository
        self.hangoutRepository = hangoutRepository
        self.preferencesService = preferencesService
    }
    
    func setAnalyticsService(_ service: AnalyticsService) {
        self.analyticsService = service
    }

    /// Returns one RelationshipHealth per active tracked contact.
    ///
    /// Uses the user's configured lookBackDays preference (default 90 days) to determine
    /// how far back to search for hangout events.
    /// Contacts with no events in this window receive a nil lastHangoutDate and
    /// the maximum possible score, surfacing them as most overdue.
    func computeHealth() async -> [RelationshipHealth] {
        let lookBackDays = preferencesService.preferences.lookAheadDays > 0 ? preferencesService.preferences.lookAheadDays : 90
        let contacts = (try? repository.fetchAll()) ?? []
        guard !contacts.isEmpty else { return [] }

        let since = Calendar.current.date(byAdding: .day, value: -lookBackDays, to: .now) ?? .now

        // Build a lookup of the nearest upcoming hangout per contact.
        // fetchUpcoming() returns results sorted by startDate ascending, so the first
        // entry per contactID is the soonest.
        let upcoming = (try? hangoutRepository.fetchUpcoming()) ?? []
        var upcomingByContactID: [UUID: ScheduledHangout] = [:]
        for hangout in upcoming {
            guard let contactID = hangout.contact?.id else { continue }
            if upcomingByContactID[contactID] == nil {
                upcomingByContactID[contactID] = hangout
            }
        }

        // Fan out to all providers concurrently. A provider that denies access or
        // throws contributes an empty result — one bad provider degrades gracefully
        // rather than aborting the whole computation.
        var allEvents: [HangoutEvent] = []
        await withTaskGroup(of: [HangoutEvent].self) { group in
            for provider in providers {
                group.addTask { [weak self] in
                    print("[RelationshipService] requesting access from \(type(of: provider))")
                    
                    // Track calendar permission request (only once)
                    if let strongSelf = self, !strongSelf.hasRequestedCalendarPermission {
                        strongSelf.analyticsService?.logPermissionRequested(type: "Calendar")
                        strongSelf.hasRequestedCalendarPermission = true
                    }
                    
                    let requestTime = Date()
                    let hasAccess = await provider.requestAccess()
                    let timeElapsed = Date().timeIntervalSince(requestTime)
                    
                    print("[RelationshipService] \(type(of: provider)) access granted: \(hasAccess)")
                    
                    // Track permission result
                    if hasAccess {
                        self?.analyticsService?.logPermissionGranted(
                            type: "Calendar",
                            timeElapsed: timeElapsed
                        )
                    } else {
                        self?.analyticsService?.logPermissionDenied(
                            type: "Calendar",
                            timeElapsed: timeElapsed
                        )
                    }
                    
                    guard hasAccess else { return [] }
                    print("[RelationshipService] calling fetchEvents on \(type(of: provider))")
                    return (try? await provider.fetchEvents(for: contacts, since: since)) ?? []
                }
            }
            for await events in group {
                allEvents.append(contentsOf: events)
            }
        }

        // Deduplicate by eventIdentifier — the same event can be returned by
        // multiple providers if they overlap (e.g. CalDAV + iCloud).
        var seen = Set<String>()
        allEvents = allEvents.filter { seen.insert($0.eventIdentifier).inserted }

        // Build a lookup of manually logged past hangouts per contact.
        // These are ScheduledHangout records with a past startDate, stored when the
        // user logs a hangout they had outside the app.
        let allHangouts = (try? hangoutRepository.fetchAll()) ?? []
        var manualLastByContactID: [UUID: (date: Date, title: String?)] = [:]
        var manualCountByContactID: [UUID: Int] = [:]
        for hangout in allHangouts where hangout.startDate <= .now && hangout.startDate >= since {
            guard let contactID = hangout.contact?.id else { continue }
            manualCountByContactID[contactID, default: 0] += 1
            if let existing = manualLastByContactID[contactID] {
                if hangout.startDate > existing.date {
                    manualLastByContactID[contactID] = (hangout.startDate, hangout.activity)
                }
            } else {
                manualLastByContactID[contactID] = (hangout.startDate, hangout.activity)
            }
        }

        return contacts.map { contact in
            let matching = allEvents.filter { event in
                event.participantMatchers.contains { $0.matches(contact) }
            }
            let lastCalEvent = matching.max(by: { $0.startDate < $1.startDate })
            let manualLast = manualLastByContactID[contact.id]

            // Merge: use whichever source recorded a more recent hangout.
            let lastHangoutDate: Date?
            let lastHangoutTitle: String?
            if let cal = lastCalEvent?.startDate, let man = manualLast?.date {
                if man >= cal {
                    lastHangoutDate = man
                    lastHangoutTitle = manualLast?.title
                } else {
                    lastHangoutDate = cal
                    lastHangoutTitle = lastCalEvent?.title.isEmpty == false ? lastCalEvent?.title : nil
                }
            } else if let cal = lastCalEvent?.startDate {
                lastHangoutDate = cal
                lastHangoutTitle = lastCalEvent?.title.isEmpty == false ? lastCalEvent?.title : nil
            } else {
                lastHangoutDate = manualLast?.date
                lastHangoutTitle = manualLast?.title
            }

            let upcomingHangout = upcomingByContactID[contact.id]
            let computedScore = score(lastHangoutDate: lastHangoutDate, lookBackDays: lookBackDays)
            return RelationshipHealth(
                contact: contact,
                lastHangoutDate: lastHangoutDate,
                lastHangoutTitle: lastHangoutTitle,
                hangoutCount: matching.count + (manualCountByContactID[contact.id] ?? 0),
                score: upcomingHangout != nil ? 0.0 : computedScore,
                upcomingHangout: upcomingHangout
            )
        }
    }

    // MARK: - Scoring

    // Score = days since last hangout, defaulting to the full look-back window when
    // there is no recorded hangout. Higher means more overdue.
    private func score(lastHangoutDate: Date?, lookBackDays: Int) -> Double {
        guard let last = lastHangoutDate else { return Double(lookBackDays) }
        let days = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? lookBackDays
        return Double(max(0, days))
    }
}
