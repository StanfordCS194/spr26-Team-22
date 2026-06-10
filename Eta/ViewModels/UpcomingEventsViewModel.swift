import Foundation

struct HangoutDisplayItem: Identifiable {
    /// The underlying model — @Observable, so status reads in a View body
    /// register observation automatically and re-render when inviteeResponse changes.
    let hangout: ScheduledHangout
    let contactName: String

    var id: UUID { hangout.id }
}

@MainActor
@Observable
final class UpcomingEventsViewModel {
    /// Events from today onwards, sorted soonest first.
    /// Includes canceled events until their intended date passes.
    private(set) var upcomingItems: [HangoutDisplayItem] = []

    /// All events ever scheduled, sorted by startDate ascending.
    /// Feeds the EventHistoryView.
    private(set) var allItems: [HangoutDisplayItem] = []

    /// Invitations received that are still awaiting a response, sorted soonest first.
    private(set) var pendingInvites: [PendingReceivedInvitation] = []

    private let hangoutRepository: ScheduledHangoutRepository
    private let pendingInviteRepository: PendingReceivedInvitationRepository
    private let invitationManager: InvitationManager
    private let formatter: ContactFormatter

    init(
        hangoutRepository: ScheduledHangoutRepository,
        pendingInviteRepository: PendingReceivedInvitationRepository,
        invitationManager: InvitationManager,
        formatter: ContactFormatter
    ) {
        self.hangoutRepository = hangoutRepository
        self.pendingInviteRepository = pendingInviteRepository
        self.invitationManager = invitationManager
        self.formatter = formatter
    }

    func refresh() async {
        do {
            let hangouts = try hangoutRepository.fetchAll()
            let startOfToday = Calendar.current.startOfDay(for: .now)

            let items: [HangoutDisplayItem] = hangouts
                .filter { $0.contact != nil || $0.contactName != nil }
                .sorted { $0.startDate < $1.startDate }
                .map { hangout in
                    let name = hangout.contact.map { formatter.displayName(for: $0) }
                        ?? hangout.contactName
                        ?? "Unknown"
                    return HangoutDisplayItem(hangout: hangout, contactName: name)
                }

            allItems = items
            upcomingItems = items.filter { $0.hangout.startDate >= startOfToday }
        } catch {
            // SwiftData fetch failed; leave existing data in place.
        }

        pendingInvites = ((try? pendingInviteRepository.fetchAll()) ?? [])
            .filter { $0.endTime > .now }
            .sorted { $0.startTime < $1.startTime }
    }

    func respond(to invite: PendingReceivedInvitation, accepted: Bool) async {
        await invitationManager.respondToRemoteInvitation(
            id: invite.id,
            accepted: accepted,
            activity: invite.activity,
            startTime: invite.startTime,
            endTime: invite.endTime,
            fromIdentifier: invite.fromIdentifier
        )
        await refresh()
    }
}
