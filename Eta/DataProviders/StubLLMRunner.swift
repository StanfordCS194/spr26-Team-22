import Foundation

/// Development placeholder for LLMRunner.
///
/// Returns a hardcoded activity phrase so the full suggestion pipeline can be
/// exercised end-to-end without a real LLM integration. Replace with a
/// SpeziLLMRunner or remote API conformer in EtaApp.swift when ready.
final class StubLLMRunner: LLMRunner {
    func generate(systemPrompt: String, userPrompt: String) async throws -> String {
        return "Grab coffee"
    }
}
