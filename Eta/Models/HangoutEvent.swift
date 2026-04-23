import Foundation

/// A single calendar event that has been parsed and identified as a potential hangout.
struct HangoutEvent: Identifiable {
    var id: String { eventIdentifier }
    var eventIdentifier: String
    var title: String
    var startDate: Date
    var endDate: Date
    /// Emails of attendees — matched against TrackedContact.emailAddress to associate contacts.
    var participantEmails: [String]
}
