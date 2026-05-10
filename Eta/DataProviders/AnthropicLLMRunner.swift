import Foundation

/// LLMRunner that calls the Anthropic Messages API via URLSession.
///
/// API key is read from the app bundle under the key `ANTHROPIC_API_KEY`.
/// Set this in Info.plist referencing a build variable (e.g. via an xcconfig file)
/// so the key is never checked into source control.
final class AnthropicLLMRunner: LLMRunner {

    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private struct ResponseBody: Decodable {
        let content: [ContentBlock]

        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }
    }

    func generate(systemPrompt: String, userPrompt: String) async throws -> String {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String,
              !apiKey.isEmpty else {
            throw LLMError.missingAPIKey
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestBody(
            model: "claude-haiku-4-5-20251001",
            max_tokens: 64,
            system: systemPrompt,
            messages: [.init(role: "user", content: userPrompt)]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw LLMError.httpError(statusCode)
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw LLMError.emptyResponse
        }
        return text
    }
}

private enum LLMError: LocalizedError {
    case missingAPIKey
    case httpError(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:  return "ANTHROPIC_API_KEY not set in app bundle."
        case .httpError(let code): return "Anthropic API returned HTTP \(code)."
        case .emptyResponse:  return "Anthropic API returned no text content."
        }
    }
}
