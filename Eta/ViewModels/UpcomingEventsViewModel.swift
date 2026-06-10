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
    private let activityStrategy: LLMActivityStrategy
    private let formatter: ContactFormatter

    init(
        hangoutRepository: ScheduledHangoutRepository,
        pendingInviteRepository: PendingReceivedInvitationRepository,
        invitationManager: InvitationManager,
        inviteService: InviteService,
        contactRepository: ContactRepository,
        activityStrategy: LLMActivityStrategy,
        formatter: ContactFormatter
    ) {
        self.hangoutRepository = hangoutRepository
        self.pendingInviteRepository = pendingInviteRepository
        self.invitationManager = invitationManager
        self.inviteService = inviteService
        self.contactRepository = contactRepository
        self.activityStrategy = activityStrategy
        self.formatter = formatter
    }

    func refresh() async {
        reloadItems()
        pendingInvites = ((try? pendingInviteRepository.fetchAll()) ?? [])
            .filter { $0.endTime > .now }
            .sorted { $0.startTime < $1.startTime }
        contacts = (try? contactRepository.fetchAll()) ?? []
    }

    private func reloadItems() {
        guard let hangouts = try? hangoutRepository.fetchAll() else { return }
        let startOfToday = Calendar.current.startOfDay(for: .now)
        let items: [HangoutDisplayItem] = hangouts
            .filter { $0.contact != nil }
            .sorted { $0.startDate < $1.startDate }
            .map { HangoutDisplayItem(hangout: $0, contactName: formatter.displayName(for: $0.contact!)) }
        allItems = items
        upcomingItems = items.filter { $0.hangout.startDate >= startOfToday }
    }

    func respond(to invite: PendingReceivedInvitation, accepted: Bool) async {
        await invitationManager.respondToRemoteInvitation(
            id: invite.id,
            accepted: accepted,
            activity: invite.activity,
            startTime: invite.startTime,
            endTime: invite.endTime,
            fromIdentifier: invite.fromIdentifier,
            isEdit: invite.isEdit,
            delayed: true
        )
        await refresh()
    }

    func hasConflict(for interval: DateInterval, excludingID: UUID? = nil) -> Bool {
        (try? hangoutRepository.hasOverlappingHangout(start: interval.start, end: interval.end, excludingID: excludingID)) ?? false
    }

    // MARK: - CRUD

    /// Books a new hangout and sends an invitation via InvitationManager.
    func addEvent(contact: TrackedContact, activity: String, interval: DateInterval, previousInvitationID: String? = nil, source: String = "manual") async {
        let suggestion = Suggestion(
            contact: contact,
            activityDescription: activity,
            reason: "Manually scheduled",
            proposedTimes: [interval],
            generatedAt: .now
        )
        guard let hangoutID = inviteService.book(suggestion: suggestion) else { return }
        let friendName = formatter.displayName(for: contact)
        _ = try? await invitationManager.acceptSuggestion(
            contact: contact,
            activityName: activity,
            friendName: friendName,
            scheduledTime: interval.start,
            endDate: interval.end,
            hangoutID: hangoutID,
            previousInvitationID: previousInvitationID,
            source: source
        )
        await refresh()
    }

    /// Cancels the existing hangout and schedules a replacement with updated details.
    /// The contact cannot be changed — only the activity, date, and duration.
    func editEvent(_ hangout: ScheduledHangout, activity: String, interval: DateInterval) async {
        guard let contact = hangout.contact else { return }
        let previousInvitationID = hangout.invitationID
        invitationManager.cancelHangoutReminders(for: hangout.id)
        try? hangoutRepository.remove(hangout)
        reloadItems()
        await addEvent(contact: contact, activity: activity, interval: interval, previousInvitationID: previousInvitationID, source: "edit")
    }

    /// Removes the hangout and cancels its associated notifications.
    /// If the event is confirmed and has a Supabase-backed invitation, notifies the other user.
    func deleteEvent(_ hangout: ScheduledHangout) {
        invitationManager.cancelHangoutReminders(for: hangout.id)
        let isConfirmedBackend = hangout.inviteeResponse == .confirmed && hangout.invitationID != nil
        let contact = hangout.contact
        let invitationID = hangout.invitationID
        let activity = hangout.activity
        try? hangoutRepository.remove(hangout)
        reloadItems()
        Task {
            if isConfirmedBackend, let contact, let invitationID {
                await invitationManager.cancelEventByValues(contact: contact, invitationID: invitationID, activity: activity)
            }
        }
    }

    /// Calls LLMActivityStrategy.propose() for the given contact and proposed time.
    /// Builds a minimal RelationshipHealth (no history) and a time-enriched PromptContext.
    /// Throws if the strategy throws — callers should surface a failure indicator, not crash.
    func suggestActivity(for contact: TrackedContact, proposedTime: DateInterval) async throws -> String? {
        let health = RelationshipHealth(
            contact: contact,
            lastHangoutDate: nil,
            lastHangoutTitle: nil,
            hangoutCount: 0,
            score: 0,
            upcomingHangout: nil
        )
        let timeString = proposedTime.start.formatted(.dateTime.weekday(.wide).hour(.defaultDigits(amPM: .abbreviated)))
        let context = PromptContext(
            relationshipFacts: [
                ContextFact(
                    description: "The user wants to meet on \(timeString)",
                    source: .onboardingPreferences
                )
            ],
            userGoals: []
        )
        return try await activityStrategy.propose(for: health, context: context)?.activityDescription
    }
}
