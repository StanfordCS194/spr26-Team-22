import Foundation
import EventKit

/// Supplies hangout events from Apple Calendar via EKEventStore.
///
/// Implements `ImplicitDataProvider`. A future social-API provider would conform
/// to the same protocol — no changes to RelationshipService needed.
final class CalendarDataProvider: ImplicitDataProvider {
    private let eventStore = EKEventStore()

    func requestAccess() async -> Bool {
        let current = EKEventStore.authorizationStatus(for: .event)
        print("[CalendarDataProvider] authorizationStatus before request: \(current.rawValue)")
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            print("[CalendarDataProvider] requestFullAccessToEvents returned: \(granted)")
            return granted
        } catch {
            print("[CalendarDataProvider] requestFullAccessToEvents threw: \(error)")
            return false
        }
    }

    /// Fetches calendar events on or after `date` and maps qualifying ones to HangoutEvents.
    ///
    /// The `contacts` parameter is part of the protocol contract and available for
    /// pre-filtering, but we intentionally do not filter here: we build a ContactMatcher
    /// for every attendee so RelationshipService can match a single event against
    /// multiple contacts in one pass. On a personal device the total event count is small
    /// enough that pre-filtering provides no meaningful benefit.
    func fetchEvents(for contacts: [TrackedContact], since date: Date) async throws -> [HangoutEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: date,
            end: Date(),
            calendars: eventStore.calendars(for: .event)
        )
        let ekEvents = eventStore.events(matching: predicate)
        
        print("Searching over \(ekEvents.count) events")
        
        let results: [HangoutEvent] = ekEvents.compactMap { event in
            guard qualifies(event) else { return nil }
            
            let matchers = buildMatchers(for: event)
            guard !matchers.isEmpty else { return nil }
            
            return HangoutEvent(
                eventIdentifier: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "",
                startDate: event.startDate,
                endDate: event.endDate,
                participantMatchers: matchers
            )
        }
        
        print("Found \(results.count) hangout events.")
        
        return results
    }
    
    // MARK: - Private helpers

    /// Returns true when the event passes all three hangout filters from CLAUDE.md:
    /// not all-day, duration ≥ 15 min, has at least one attendee.
    private func qualifies(_ event: EKEvent) -> Bool {
        guard !event.isAllDay,
              let end = event.endDate,
              end.timeIntervalSince(event.startDate) >= 15 * 60,
              let attendees = event.attendees, !attendees.isEmpty
        else { return false }
        return true
    }

    /// Builds one ContactMatcher per attendee, skipping the current user and
    /// anyone who declined. Prefers email when available; falls back to name.
    private func buildMatchers(for event: EKEvent) -> [ContactMatcher] {
        guard let attendees = event.attendees else { return [] }

        return attendees.compactMap { participant in
            // Exclude the device owner — we want who they hung out WITH.
            guard !participant.isCurrentUser else { return nil }
            // Exclude non-persons (rooms, resources).
            guard participant.participantType == .person else { return nil }
            // Exclude people who explicitly said no.
            guard participant.participantStatus != .declined else { return nil }

            let urlString = participant.url.absoluteString
            if urlString.hasPrefix("mailto:") {
                let email = String(urlString.dropFirst("mailto:".count)).lowercased()
                if !email.isEmpty { return .email(email) }
            }

            // No usable email URL — fall back to display name matching.
            // Note: EKParticipant does not expose phone numbers, so name is the
            // only available fallback for contacts without email addresses.
            if let name = participant.name, !name.isEmpty {
                return .name(name.lowercased())
            }

            return nil
        }
    }
}
