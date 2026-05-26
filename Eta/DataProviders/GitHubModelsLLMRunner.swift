import Foundation

/// LLMRunner that calls the GitHub Models inference API (OpenAI-compatible) via URLSession.
///
/// API key is a GitHub personal access token read from the app bundle under `LLM_API_KEY`.
/// Set this in Info.plist referencing a build variable (e.g. via an xcconfig file)
/// so the key is never checked into source control.
final class GitHubModelsLLMRunner: LLMRunner {

    enum Model: String {
        case gpt4oMini  = "gpt-4o-mini"
        case llama31_8b = "meta-llama-3.1-8b-instruct"
    }

    private let model: Model

    init(model: Model = .gpt4oMini) {
        self.model = model
    }

    // MARK: — LLMRunner

    func generate(systemPrompt: String, userPrompt: String) async throws -> String {
        try await execute(apiMessages: [
            .init(role: "system", content: systemPrompt),
            .init(role: "user",   content: userPrompt)
        ])
    }

    /// Overrides the default transcript fallback with proper multi-turn role separation.
    func generate(messages: [LLMMessage]) async throws -> String {
        let apiMessages = messages.map { msg -> APIMessage in
            let role: String = switch msg.role {
            case .system:    "system"
            case .user:      "user"
            case .assistant: "assistant"
            }
            return APIMessage(role: role, content: msg.content)
        }
        return try await execute(apiMessages: apiMessages, maxTokens: 128)
    }

    // MARK: — Private

    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let messages: [APIMessage]
    }

    private struct APIMessage: Encodable {
        let role: String
        let content: String
    }

    private struct ResponseBody: Decodable {
        let choices: [Choice]
        struct Choice: Decodable {
            let message: Message
            struct Message: Decodable {
                let content: String
            }
        }
    }

    private func execute(apiMessages: [APIMessage], maxTokens: Int = 64) async throws -> String {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "LLM_API_KEY") as? String,
              !apiKey.isEmpty else {
            throw LLMError.noAPIKey
        }

        let url = URL(string: "https://models.inference.ai.azure.com/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestBody(model: model.rawValue, max_tokens: maxTokens, messages: apiMessages)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw LLMError.httpError(code)
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let text = decoded.choices.first?.message.content else {
            throw LLMError.emptyResponse
        }

        print("[GitHubLLMRunner] \(model.rawValue): \(text)")
        return text
    }
}

private enum LLMError: LocalizedError {
    case noAPIKey
    case httpError(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey:           return "LLM_API_KEY is missing or empty in Info.plist."
        case .httpError(let code): return "GitHub Models API returned HTTP \(code)."
        case .emptyResponse:      return "GitHub Models API returned no text content."
        }
    }
}
