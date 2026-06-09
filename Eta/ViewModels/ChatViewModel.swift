import Foundation

/// Drives the in-app LLM chat interface.
///
/// Builds a context-aware system prompt from the current contact list and health scores,
/// then manages a multi-turn conversation via ChatService.
/// Once the model identifies an intent and emits a function call, the ViewModel exposes
/// it as `pendingFunctionCall` for the View to confirm and invoke.
@Observable
final class ChatViewModel {

    private(set) var messages: [ChatMessage] = []
    private(set) var isSending = false
    private(set) var pendingFunctionCall: ChatFunctionCall?
    private(set) var invokedAction: ChatFunctionCall?
    /// Set to true after an action completes. The presenting view should dismiss when this fires.
    private(set) var shouldDismiss = false

    private let contactRepository: ContactRepository
    private let inviteService: InviteService
    private let invitationManager: InvitationManager
    private let availabilityDataProvider: AvailabilityDataProvider
    private let goalRepository: GoalRepository

    /// Lazily built on first send so it captures current contact + health data.
    private var chatService: ChatService?

    init(
        contactRepository: ContactRepository,
        inviteService: InviteService,
        invitationManager: InvitationManager,
        availabilityDataProvider: AvailabilityDataProvider,
        goalRepository: GoalRepository
    ) {
        self.contactRepository = contactRepository
        self.inviteService = inviteService
        self.invitationManager = invitationManager
        self.availabilityDataProvider = availabilityDataProvider
        self.goalRepository = goalRepository
    }

    // MARK: — Conversation

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        if chatService == nil {
            chatService = ChatService(systemPrompt: buildSystemPrompt())
        }

        let userMessage = ChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        isSending = true

        let (reply, call) = await chatService!.send(messages: messages)

        let assistantMessage = ChatMessage(role: .assistant, content: reply, functionCall: call)
        messages.append(assistantMessage)
        if let call { pendingFunctionCall = call }
        isSending = false
    }

    /// Called when the user taps the confirm button on a pending function call.
    func invokeAction(_ call: ChatFunctionCall) {
        switch call {
        case .scheduleHangout(let friendName, let activity, let proposedTime):
            scheduleHangout(friendName: friendName, activity: activity, proposedTimeString: proposedTime)
        case .setGoal(let friendName, let goal):
            setGoal(friendName: friendName, goal: goal)
        }
        invokedAction = call
        pendingFunctionCall = nil
    }

    /// Clears the session so the next chat open starts fresh.
    func reset() {
        messages = []
        pendingFunctionCall = nil
        invokedAction = nil
        chatService = nil
        shouldDismiss = false
    }

    // MARK: — Private actions

    private func scheduleHangout(friendName: String, activity: String, proposedTimeString: String) {
        guard let contact = resolveContact(named: friendName) else { return }

        Task { @MainActor in
            let interval: DateInterval
            if let parsed = parseDate(from: proposedTimeString) {
                interval = DateInterval(start: parsed, duration: 3600)
            } else if let slots = try? await availabilityDataProvider.findAvailableSlots(),
                      let first = slots.first {
                interval = first
            } else {
                return
            }

            let suggestion = Suggestion(
                contact: contact,
                activityDescription: activity,
                reason: "Scheduled via chat",
                proposedTimes: [interval],
                generatedAt: .now
            )
            guard let hangoutID = inviteService.book(suggestion: suggestion) else { return }
            _ = try? await invitationManager.acceptSuggestion(
                contact: contact,
                activityName: activity,
                friendName: friendName,
                scheduledTime: interval.start,
                endDate: interval.end,
                hangoutID: hangoutID
            )
            shouldDismiss = true
        }
    }

    private func setGoal(friendName: String, goal: String) {
        guard let contact = resolveContact(named: friendName) else { return }
        let now = Date()
        let cadence = GoalCadence.monthly
        let windowEnd = Calendar.current.date(
            byAdding: .day, value: cadence.durationInDays, to: now
        ) ?? now
        let newGoal = Goal(
            title: goal,
            friendIDs: [contact.id],
            cadence: cadence,
            target: 2,
            windowStart: now,
            windowEnd: windowEnd,
            source: .aiAccepted
        )
        try? goalRepository.add(newGoal)
        shouldDismiss = true
    }

    // MARK: — Helpers

    /// Case-insensitive match on given name, full name, or stored display name.
    /// Fetches directly from the repository so the result is always up-to-date.
    private func resolveContact(named name: String) -> TrackedContact? {
        let contacts = (try? contactRepository.fetchAll()) ?? []
        let lower = name.lowercased()
        return contacts.first {
            $0.givenName.lowercased() == lower
            || "\($0.givenName) \($0.familyName)".lowercased() == lower
            || $0.name.lowercased().contains(lower)
        }
    }

    /// Extracts the first concrete date from a natural-language string using NSDataDetector.
    private func parseDate(from string: String) -> Date? {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.date.rawValue
        ) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        return detector.firstMatch(in: string, options: [], range: range)?.date
    }

    // MARK: — System prompt

    private func buildSystemPrompt() -> String {
        let contacts = (try? contactRepository.fetchAll()) ?? []

        let friendList: String = contacts.isEmpty ? "none" : contacts.map { contact in
            "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        }.joined(separator: ", ")

        return """
        You are Eta, a concise assistant in a friendship app.

        You can invoke two functions:
          scheduleHangout(friendName, activity, proposedTime)
          setGoal(friendName, goal)

        Rules:
        - friendName must exactly match one of the friends listed below. If the user's phrasing is ambiguous or doesn't clearly map to one name, ask one short clarifying question before calling the function.
        - Fill in all other missing details (activity, time, goal wording) with a reasonable guess — don't ask about them.
        - Resolve the intent within 1–3 messages. Prefer acting immediately when the friend is unambiguous.

        When you are ready to act, respond with one short confirming sentence followed immediately by the function call on the next line:
        <<FUNCTION_CALL>>{"function":"<name>","args":{"key":"value"}}<</FUNCTION_CALL>>

        Example (unambiguous):
        User: Schedule dinner with Sarah
        Assistant: I'll book dinner with Sarah for this Friday at 7pm!
        <<FUNCTION_CALL>>{"function":"scheduleHangout","args":{"friendName":"Sarah Johnson","activity":"Dinner","proposedTime":"this Friday at 7pm"}}<</FUNCTION_CALL>>

        Example (ambiguous name):
        User: Schedule something with Alex
        Assistant: I see two Alexes — Alex Chen or Alex Rivera. Which one did you mean?

        Friends: \(friendList)
        """
    }
}
