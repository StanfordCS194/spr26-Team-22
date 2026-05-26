import Foundation

/// A single message in an LLM conversation.
struct LLMMessage {
    enum Role { case system, user, assistant }
    let role: Role
    let content: String
}

/// Executes a prompt against a language model and returns the raw text response.
///
/// This protocol is intentionally thin — it knows nothing about suggestions,
/// contacts, or activities. Prompt construction and response parsing are
/// the responsibility of the caller (LLMActivityStrategy, ChatService, etc.).
///
/// Today: GitHubModelsLLMRunner (remote API).
/// Tomorrow: SpeziLLMRunner (on-device) or any other conformer.
/// Swap implementations in EtaApp.swift without touching any strategy code.
protocol LLMRunner {
    /// Single-turn convenience: system prompt + one user message.
    func generate(systemPrompt: String, userPrompt: String) async throws -> String

    /// Multi-turn: full message history including system, user, and assistant turns.
    /// Default implementation serialises the history as a transcript and delegates
    /// to the single-turn method — conformers can override for native multi-turn support.
    func generate(messages: [LLMMessage]) async throws -> String
}

extension LLMRunner {
    func generate(messages: [LLMMessage]) async throws -> String {
        let system = messages.first { $0.role == .system }?.content ?? ""
        let transcript = messages
            .filter { $0.role != .system }
            .map { ($0.role == .user ? "User" : "Assistant") + ": " + $0.content }
            .joined(separator: "\n")
        return try await generate(systemPrompt: system, userPrompt: transcript)
    }
}
