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

    // Set after the user confirms a pending function call.
    private(set) var invokedAction: ChatFunctionCall?

    private let connectionsViewModel: ConnectionsViewModel
    /// Lazily built on first send so it captures current contact + health data.
    private var chatService: ChatService?

    init(connectionsViewModel: ConnectionsViewModel) {
        self.connectionsViewModel = connectionsViewModel
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
    /// The body of each case is intentionally left empty — implementation comes later.
    func invokeAction(_ call: ChatFunctionCall) {
        switch call {
        case .scheduleHangout:
            break
        case .reflectOnTrends:
            break
        case .setGoal:
            break
        case .provideFeedback:
            break
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
    }

    // MARK: — System prompt

    private func buildSystemPrompt() -> String {
        let contacts = connectionsViewModel.contacts
        let healthScores = connectionsViewModel.healthScores

        let friendList: String = contacts.isEmpty ? "none" : contacts.map { contact in
            let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let days = healthScores[contact.id]?.daysSinceLastHangout.map { "\($0)d ago" } ?? "never seen"
            return "\(name) (\(days))"
        }.joined(separator: ", ")

        return """
        You are Eta, a concise assistant in a friendship app. When the user says what they want, invoke the right function immediately. Fill in any missing details with a reasonable guess — do not ask for them.

        Functions:
          scheduleHangout(friendName, activity, proposedTime)
          reflectOnTrends(period)
          setGoal(friendName, goal)
          provideFeedback(friendName, activity, sentiment: positive|negative|neutral)

        Format: one short sentence confirming the action, then on the very next line:
        <<FUNCTION_CALL>>{"function":"<name>","args":{"key":"value"}}<</FUNCTION_CALL>>

        Example:
        User: Schedule dinner with Johnny somewhere nice
        Assistant: I'll book a nice Italian dinner with Johnny for Friday at 7pm!
        <<FUNCTION_CALL>>{"function":"scheduleHangout","args":{"friendName":"Johnny","activity":"Italian dinner","proposedTime":"Friday at 7pm"}}<</FUNCTION_CALL>>

        Only ask a clarifying question if the user's intent is genuinely ambiguous (e.g. two friends with the same name). Otherwise act immediately.

        Friends: \(friendList)
        """
    }
}
