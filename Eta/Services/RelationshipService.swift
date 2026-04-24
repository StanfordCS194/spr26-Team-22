import Foundation

/// Computes RelationshipHealth for every tracked contact by fanning out
/// to all registered ImplicitDataProviders and correlating their events.
final class RelationshipService {
    private let providers: [any ImplicitDataProvider]
    private let repository: ContactRepository
    private let hangoutRepository: ScheduledHangoutRepository

    init(
        providers: [any ImplicitDataProvider],
        repository: ContactRepository,
        hangoutRepository: ScheduledHangoutRepository
    ) {
        self.providers = providers
        self.repository = repository
        self.hangoutRepository = hangoutRepository
    }

    /// Returns one RelationshipHealth per active tracked contact.
    ///
    /// - Parameter lookBackDays: How far back to search for hangout events (default 90 days).
    ///   Contacts with no events in this window receive a nil lastHangoutDate and
    ///   the maximum possible score, surfacing them as most overdue.
    func computeHealth(lookBackDays: Int = 90) async -> [RelationshipHealth] {
        let contacts = (try? repository.fetchAll()) ?? []
        guard !contacts.isEmpty else { return [] }

        let since = Calendar.current.date(byAdding: .day, value: -lookBackDays, to: .now) ?? .now

        // Build a lookup of the nearest upcoming hangout per contact.
        // fetchUpcoming() returns results sorted by startDate ascending, so the first
        // entry per contactID is the soonest.
        let upcoming = (try? hangoutRepository.fetchUpcoming()) ?? []
        var upcomingByContactID: [UUID: ScheduledHangout] = [:]
        for hangout in upcoming {
            if upcomingByContactID[hangout.contactID] == nil {
                upcomingByContactID[hangout.contactID] = hangout
            }
        }

        // Fan out to all providers concurrently. A provider that denies access or
        // throws contributes an empty result — one bad provider degrades gracefully
        // rather than aborting the whole computation.
        var allEvents: [HangoutEvent] = []
        await withTaskGroup(of: [HangoutEvent].self) { group in
            for provider in providers {
                group.addTask {
                    print("[RelationshipService] requesting access from \(type(of: provider))")
                    let hasAccess = await provider.requestAccess()
                    print("[RelationshipService] \(type(of: provider)) access granted: \(hasAccess)")
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

        return contacts.map { contact in
            let matching = allEvents.filter { event in
                event.participantMatchers.contains { $0.matches(contact) }
            }
            let lastEvent = matching.max(by: { $0.startDate < $1.startDate })
            let lastHangoutDate = lastEvent?.startDate
            let upcomingHangout = upcomingByContactID[contact.id]
            // Suppress the overdue score when a hangout is already on the books —
            // score 0 falls below the strategy's threshold so this contact won't
            // be suggested again until the scheduled hangout passes.
            let computedScore = score(lastHangoutDate: lastHangoutDate, lookBackDays: lookBackDays)
            return RelationshipHealth(
                contact: contact,
                lastHangoutDate: lastHangoutDate,
                lastHangoutTitle: lastEvent?.title.isEmpty == false ? lastEvent?.title : nil,
                hangoutCount: matching.count,
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
