import Foundation

/// Manages a multi-turn LLM conversation for the in-app chat interface.
///
/// Converts the app's ChatMessage history into LLMMessages and delegates to any LLMRunner.
/// Function call detection uses a `<<FUNCTION_CALL>>…<</FUNCTION_CALL>>` block
/// that the model is prompted to emit once it has all required arguments.
final class ChatService {

    private let runner: any LLMRunner
    private let systemPrompt: String

    init(systemPrompt: String, runner: any LLMRunner = GitHubModelsLLMRunner()) {
        self.systemPrompt = systemPrompt
        self.runner = runner
    }

    // MARK: — Send

    /// Sends the full conversation history and returns the model's reply plus any parsed function call.
    func send(messages: [ChatMessage]) async -> (reply: String, functionCall: ChatFunctionCall?) {
        var llmMessages: [LLMMessage] = [.init(role: .system, content: systemPrompt)]
        llmMessages += messages.map { msg in
            .init(role: msg.role == .user ? .user : .assistant, content: msg.content)
        }

        let raw: String
        do {
            raw = try await runner.generate(messages: llmMessages)
        } catch {
            print("[ChatService] runner error: \(error)")
            return ("Something went wrong. Try again?", nil)
        }

        return parseFunctionCall(from: raw)
    }

    // MARK: — Function call parsing

    private func parseFunctionCall(from text: String) -> (String, ChatFunctionCall?) {
        let open  = "<<FUNCTION_CALL>>"
        let close = "<</FUNCTION_CALL>>"

        guard let startRange = text.range(of: open),
              let endRange   = text.range(of: close),
              startRange.upperBound <= endRange.lowerBound else {
            return (text.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }

        let jsonString = String(text[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let humanText  = String(text[..<startRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let call = decodeCall(jsonString)
        print("[ChatService] Function call: \(jsonString)")
        return (humanText.isEmpty ? "Got it — ready to go!" : humanText, call)
    }

    private func decodeCall(_ json: String) -> ChatFunctionCall? {
        guard let data = json.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fn   = obj["function"] as? String,
              let args = obj["args"] as? [String: String] else { return nil }

        switch fn {
        case "scheduleHangout":
            guard let friend   = args["friendName"],
                  let activity = args["activity"],
                  let time     = args["proposedTime"] else { return nil }
            return .scheduleHangout(friendName: friend, activity: activity, proposedTime: time)

        case "setGoal":
            guard let friend = args["friendName"],
                  let goal   = args["goal"] else { return nil }
            return .setGoal(friendName: friend, goal: goal)

        default:
            return nil
        }
    }
}
