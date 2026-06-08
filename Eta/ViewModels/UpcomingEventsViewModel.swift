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

    /// All tracked contacts — used to populate the add-event contact picker.
    private(set) var contacts: [TrackedContact] = []

    private let hangoutRepository: ScheduledHangoutRepository
    private let pendingInviteRepository: PendingReceivedInvitationRepository
    private let invitationManager: InvitationManager
    private let inviteService: InviteService
    private let contactRepository: ContactRepository
    private let formatter: ContactFormatter

    init(
        hangoutRepository: ScheduledHangoutRepository,
        pendingInviteRepository: PendingReceivedInvitationRepository,
        invitationManager: InvitationManager,
        inviteService: InviteService,
        contactRepository: ContactRepository,
        formatter: ContactFormatter
    ) {
        self.hangoutRepository = hangoutRepository
        self.pendingInviteRepository = pendingInviteRepository
        self.invitationManager = invitationManager
        self.inviteService = inviteService
        self.contactRepository = contactRepository
        self.formatter = formatter
    }

    func refresh() async {
        do {
            let hangouts = try hangoutRepository.fetchAll()
            let startOfToday = Calendar.current.startOfDay(for: .now)

            let items: [HangoutDisplayItem] = hangouts
                .filter { $0.contact != nil }
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

        pendingInvites = ((try? pendingInviteRepository.fetchAll()) ?? [])
            .filter { $0.endTime > .now }
            .sorted { $0.startTime < $1.startTime }

        contacts = (try? contactRepository.fetchAll()) ?? []
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

    // MARK: - CRUD

    /// Books a new hangout and sends an invitation via InvitationManager.
    func addEvent(contact: TrackedContact, activity: String, interval: DateInterval) async {
        let suggestion = Suggestion(
            contact: contact,
            activityDescription: activity,
            reason: "Manually scheduled",
            proposedTimes: [interval],
            generatedAt: .now
        )
        let hangoutID = inviteService.book(suggestion: suggestion)
        let friendName = formatter.displayName(for: contact)
        _ = try? await invitationManager.acceptSuggestion(
            contact: contact,
            activityName: activity,
            friendName: friendName,
            scheduledTime: interval.start,
            endDate: interval.end,
            hangoutID: hangoutID
        )
        await refresh()
    }

    /// Cancels the existing hangout and schedules a replacement with updated details.
    /// The contact cannot be changed — only the activity, date, and duration.
    func editEvent(_ hangout: ScheduledHangout, activity: String, interval: DateInterval) async {
        guard let contact = hangout.contact else { return }
        invitationManager.cancelHangoutReminders(for: hangout.id)
        try? hangoutRepository.remove(hangout)
        await addEvent(contact: contact, activity: activity, interval: interval)
    }

    /// Removes the hangout and cancels its associated notifications.
    func deleteEvent(_ hangout: ScheduledHangout) {
        invitationManager.cancelHangoutReminders(for: hangout.id)
        try? hangoutRepository.remove(hangout)
        Task { await refresh() }
    }
}
