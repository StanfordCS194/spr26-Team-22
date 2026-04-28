import Foundation

struct HangoutDisplayItem: Identifiable {
    /// The underlying model — @Observable, so status reads in a View body
    /// register observation automatically and re-render when inviteeResponse changes.
    let hangout: ScheduledHangout
    let contactName: String

    var id: UUID { hangout.id }
}

@Observable
final class UpcomingEventsViewModel {
    /// Events from today onwards, sorted soonest first.
    /// Includes canceled events until their intended date passes.
    private(set) var upcomingItems: [HangoutDisplayItem] = []

    /// All events ever scheduled, sorted by startDate ascending.
    /// Feeds the EventHistoryView.
    private(set) var allItems: [HangoutDisplayItem] = []

    /// All tracked contacts — supplied to HangoutFormSheet for the contact picker.
    private(set) var contacts: [TrackedContact] = []

    private let hangoutRepository: ScheduledHangoutRepository
    private let contactRepository: ContactRepository
    private let formatter: ContactFormatter

    init(
        hangoutRepository: ScheduledHangoutRepository,
        contactRepository: ContactRepository,
        formatter: ContactFormatter
    ) {
        self.hangoutRepository = hangoutRepository
        self.contactRepository = contactRepository
        self.formatter = formatter
    }

    func refresh() async {
        do {
            let hangouts = try hangoutRepository.fetchAll()
            contacts = try contactRepository.fetchAll()
            let startOfToday = Calendar.current.startOfDay(for: .now)

            let items: [HangoutDisplayItem] = hangouts
                .sorted { $0.startDate < $1.startDate }
                .map { hangout in
                    let name = hangout.contact.map { formatter.displayName(for: $0) } ?? "Unknown"
                    return HangoutDisplayItem(hangout: hangout, contactName: name)
                }

            allItems = items
            upcomingItems = items.filter { $0.hangout.startDate >= startOfToday }
        } catch {
            // SwiftData fetch failed; leave existing data in place.
        }
    }

    /// Formatted display name for a contact — for use in the form sheet picker.
    func contactDisplayName(for contact: TrackedContact) -> String {
        formatter.displayName(for: contact)
    }

    func deleteHangout(_ hangout: ScheduledHangout) async {
        try? hangoutRepository.remove(hangout)
        await refresh()
    }
}
