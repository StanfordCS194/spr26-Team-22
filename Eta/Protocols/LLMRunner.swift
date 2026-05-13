import Foundation

/// Executes a prompt against a language model and returns the raw text response.
///
/// This protocol is intentionally thin — it knows nothing about suggestions,
/// contacts, or activities. Prompt construction and response parsing are
/// the responsibility of the caller (LLMActivityStrategy).
///
/// Today: StubLLMRunner (returns hardcoded text for development/testing).
/// Tomorrow: SpeziLLMRunner (on-device) or a remote API conformer.
/// Swap implementations in EtaApp.swift without touching any strategy code.
protocol LLMRunner {
    /// Sends the given prompt to the underlying model and returns the raw response string.
    func generate(systemPrompt: String, userPrompt: String) async throws -> String
}
