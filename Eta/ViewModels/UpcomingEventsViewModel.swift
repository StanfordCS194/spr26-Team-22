import Foundation

struct HangoutDisplayItem: Identifiable {
    let hangout: ScheduledHangout
    let contactName: String

    var id: UUID { hangout.id }
}

@Observable
final class UpcomingEventsViewModel {
    private(set) var upcomingItems: [HangoutDisplayItem] = []
    private(set) var allItems: [HangoutDisplayItem] = []

    private let hangoutRepository: ScheduledHangoutRepository
    private let contactRepository: ContactRepository
    private let formatter: ContactFormatter

    init(hangoutRepository: ScheduledHangoutRepository,
         contactRepository: ContactRepository,
         formatter: ContactFormatter) {
        self.hangoutRepository = hangoutRepository
        self.contactRepository = contactRepository
        self.formatter = formatter
    }

    func refresh() async {
        do {
            let hangouts = try hangoutRepository.fetchAll()
            let startOfToday = Calendar.current.startOfDay(for: .now)

            let items: [HangoutDisplayItem] = hangouts
                .sorted { $0.startDate < $1.startDate }
                .map { hangout in
                    let contact = contactRepository.fetch(by: hangout.contactID)
                    let name = contact.map { formatter.displayName(for: $0) } ?? "Unknown"
                    return HangoutDisplayItem(hangout: hangout, contactName: name)
                }

            allItems = items
            upcomingItems = items.filter { $0.hangout.startDate >= startOfToday }
        } catch {
            // SwiftData fetch failed; leave existing data in place.
        }
    }
}