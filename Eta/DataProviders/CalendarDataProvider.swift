import Foundation
import EventKit

/// Supplies hangout events from Apple Calendar via EKEventStore.
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
    
    // MARK: - Free slot detection

    /// Returns the earliest free slot in the user's calendar within `lookAheadDays` days
    /// that is at least `minimumDuration` seconds long, or nil if none is found.
    ///
    /// Search window per day: 9am–9pm. For today, the window starts at the current time
    /// if it falls within the window.
    ///
    /// This method is not on ImplicitDataProvider — free slot detection is a distinct
    /// capability from historical event fetching. SuggestionService depends on this
    /// concretely. See CLAUDE.md "What is intentionally NOT abstracted".
    func findFreeSlot(within lookAheadDays: Int = 3, minimumDuration: TimeInterval = 3600) -> DateInterval? {
        let cal = Calendar.current
        let now = Date()

        for dayOffset in 0..<lookAheadDays {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: now),
                  let windowStart = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day),
                  let windowEnd   = cal.date(bySettingHour: 21, minute: 0, second: 0, of: day)
            else { continue }

            // On the current day, don't look at time that has already passed.
            let searchStart = (dayOffset == 0) ? max(now, windowStart) : windowStart
            guard searchStart + minimumDuration <= windowEnd else { continue }

            let predicate = eventStore.predicateForEvents(
                withStart: windowStart,
                end: windowEnd,
                calendars: eventStore.calendars(for: .event)
            )
            let busyEvents = eventStore.events(matching: predicate)
                .filter { !$0.isAllDay }
                .sorted { $0.startDate < $1.startDate }

            // Walk through busy blocks and find the first gap that fits.
            var cursor = searchStart
            for event in busyEvents {
                let blockStart = max(event.startDate, windowStart)
                let blockEnd   = min(event.endDate,   windowEnd)
                if cursor + minimumDuration <= blockStart {
                    return DateInterval(start: cursor, duration: minimumDuration)
                }
                if blockEnd > cursor { cursor = blockEnd }
            }
            // Check remaining time after all events.
            if cursor + minimumDuration <= windowEnd {
                return DateInterval(start: cursor, duration: minimumDuration)
            }
        }
        return nil
    }

    // MARK: - Event creation

    /// Creates a calendar event on the user's default calendar for the given suggestion.
    /// Requires calendar access to have been granted via requestAccess().
    /// Fails silently if the event store is unavailable or access has not been granted.
    func createEvent(for suggestion: Suggestion) {
        let event = EKEvent(eventStore: eventStore)
        let firstName = suggestion.contact.givenName.isEmpty ? suggestion.contact.name : suggestion.contact.givenName
        event.title = "\(suggestion.activity.rawValue) with \(firstName)"
        event.startDate = suggestion.proposedTime.start
        event.endDate = suggestion.proposedTime.end
        event.notes = suggestion.reason
        event.calendar = eventStore.defaultCalendarForNewEvents
        try? eventStore.save(event, span: .thisEvent)
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
