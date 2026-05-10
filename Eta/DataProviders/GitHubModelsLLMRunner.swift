import Foundation

/// LLMRunner that calls the GitHub Models inference API (OpenAI-compatible) via URLSession.
///
/// Uses Meta Llama 3.1 8B Instruct — free under the GitHub Models free tier.
/// API key is a GitHub personal access token read from the app bundle under `GITHUB_TOKEN`.
/// Set this in Info.plist referencing a build variable (e.g. via an xcconfig file)
/// so the key is never checked into source control.
final class GitHubModelsLLMRunner: LLMRunner {

    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let messages: [Message]

        struct Message: Encodable {
            let role: String
            let content: String
        }
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

    func generate(systemPrompt: String, userPrompt: String) async throws -> String {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "LLM_API_KEY") as? String,
              !apiKey.isEmpty else {
            return Activity.allCases.randomElement()?.description ?? "Grab coffee"
        }

        let url = URL(string: "https://models.inference.ai.azure.com/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestBody(
            model: "meta-llama-3.1-8b-instruct",
            max_tokens: 64,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw LLMError.httpError(statusCode)
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let text = decoded.choices.first?.message.content else {
            throw LLMError.emptyResponse
        }
        return text
    }
}

private enum LLMError: LocalizedError {
    case httpError(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "GitHub Models API returned HTTP \(code)."
        case .emptyResponse:      return "GitHub Models API returned no text content."
        }
    }
}
