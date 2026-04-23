import Foundation

/// Computes RelationshipHealth for every tracked contact by fanning out
/// to all registered ImplicitDataProviders and correlating their events.
final class RelationshipService {
    private let providers: [any ImplicitDataProvider]
    private let repository: ContactRepository

    init(providers: [any ImplicitDataProvider], repository: ContactRepository) {
        self.providers = providers
        self.repository = repository
    }

    /// Returns one RelationshipHealth per active tracked contact.
    ///
    /// - Parameter lookBackDays: How far back to search for hangout events (default 90 days).
    ///   Contacts with no events in this window receive a nil lastHangoutDate and
    ///   the maximum possible score, surfacing them as most overdue.
    func computeHealth(lookBackDays: Int = 90) async -> [RelationshipHealth] {
        let contacts = (try? repository.fetchAll()) ?? []
        guard !contacts.isEmpty else { return [] }
        
        print("Computing health")

        let since = Calendar.current.date(byAdding: .day, value: -lookBackDays, to: .now) ?? .now

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
        
        print("[RelationshipService] Found \(allEvents.count) events.")

        return contacts.map { contact in
            let matching = allEvents.filter { event in
                event.participantMatchers.contains { $0.matches(contact) }
            }
            return RelationshipHealth(
                contact: contact,
                lastHangoutDate: matching.map(\.startDate).max(),
                hangoutCount: matching.count,
                score: score(lastHangoutDate: matching.map(\.startDate).max(),
                             lookBackDays: lookBackDays)
            )
        }
    }

    // MARK: - Scoring

    // Score = days since last hangout, defaulting to the full look-back window when
    // there is no recorded hangout. Higher means more overdue.
    // This is intentionally simple for MVP — it lives here as a private method so
    // the formula can be swapped without touching any call sites.
    private func score(lastHangoutDate: Date?, lookBackDays: Int) -> Double {
        guard let last = lastHangoutDate else { return Double(lookBackDays) }
        let days = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? lookBackDays
        return Double(max(0, days))
    }
}
