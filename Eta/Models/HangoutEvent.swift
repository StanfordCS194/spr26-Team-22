import Foundation

// Matching attendees to TrackedContacts requires checking different fields depending
// on what data is available. We originally considered two parallel arrays
// (participantEmails and participantNames), but parallel arrays force the caller to
// know which array to compare against which contact property — the matching rule is
// split across two sites. Instead, each attendee becomes a ContactMatcher: a
// self-contained predicate that knows both the value and how to compare it.
// Adding a new signal is a new case here — no changes needed in RelationshipService
// or provider call sites.

enum ContactMatcher {
    /// A lowercased email address.
    case email(String)
    /// A lowercased display name in "GivenName FamilyName" order.
    case name(String)

    /// Returns true if this matcher identifies `contact` as the attendee.
    func matches(_ contact: TrackedContact) -> Bool {
        switch self {
        case .email(let email):
            return contact.emailAddress?.lowercased() == email

        case .name(let name):
            // Construct the contact's name given-first, family-second rather than
            // using contact.name, which may
            // be locale-formatted (e.g. "Smith John" in some regions).
            let full = "\(contact.givenName) \(contact.familyName)"
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            return name == full
        }
    }
}

/// A single externally identified candidate hangout.
struct HangoutEvent: Identifiable {
    var id: String { eventIdentifier }
    var eventIdentifier: String
    var title: String
    var startDate: Date
    var endDate: Date
    /// One matcher per attendee. RelationshipService calls matcher.matches(contact)
    /// to associate this event with each TrackedContact.
    var participantMatchers: [ContactMatcher]
}
