import Foundation
import Security

enum CoachAIKeychain {
    private static let service = "ript.coach.ai"
    private static let account = "openai.api.key"

    static func readAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func saveAPIKey(_ apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, let data = trimmed.data(using: .utf8) else { return }

        deleteAPIKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }

    static var hasAPIKey: Bool {
        readAPIKey()?.isEmpty == false
    }
}

struct CoachTranscriptMessage {
    let role: String
    let content: String
}

struct CoachPromptSnapshot {
    let readiness: String
    let primarySummary: String
    let topPriorities: [String]
    let guardrails: [String]
    let workoutRows: [String]
    let healthRows: [String]
    let mealRows: [String]
    let reflectionRows: [String]
    let weekRows: [String]

    var promptText: String {
        """
        Today Read: \(readiness)
        Primary Summary: \(primarySummary)

        Coach Brief:
        \(topPriorities.map { "- \($0)" }.joined(separator: "\n"))

        Recovery Guardrails:
        \(guardrails.map { "- \($0)" }.joined(separator: "\n"))

        Workout Context:
        \(workoutRows.map { "- \($0)" }.joined(separator: "\n"))

        Apple Health Context:
        \(healthRows.map { "- \($0)" }.joined(separator: "\n"))

        Meals and Fuel Context:
        \(mealRows.map { "- \($0)" }.joined(separator: "\n"))

        Reflection Context:
        \(reflectionRows.map { "- \($0)" }.joined(separator: "\n"))

        Week Snapshot:
        \(weekRows.map { "- \($0)" }.joined(separator: "\n"))
        """
    }
}

enum CoachAIResponseMode: String, CaseIterable, Identifiable {
    case fast
    case balanced
    case best

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast:
            return "Fast"
        case .balanced:
            return "Balanced"
        case .best:
            return "Best"
        }
    }

    var model: String {
        switch self {
        case .fast:
            return "gpt-5.4-mini"
        case .balanced:
            return "gpt-5.4"
        case .best:
            return "gpt-5.5"
        }
    }

    var responseGuidance: String {
        switch self {
        case .fast:
            return "Fast mode: reply in 1 to 3 short sentences, no bullets, and stay under 55 words."
        case .balanced:
            return "Balanced mode: reply in 2 to 5 short sentences and stay direct."
        case .best:
            return "Best mode: reply in 3 to 6 short sentences when nuance helps, but stay concise."
        }
    }

    var maxOutputTokens: Int {
        switch self {
        case .fast:
            return 140
        case .balanced:
            return 260
        case .best:
            return 360
        }
    }

    static func mode(for model: String) -> CoachAIResponseMode {
        allCases.first { $0.model == model } ?? .balanced
    }

    static func isSupportedModel(_ model: String) -> Bool {
        allCases.contains { $0.model == model }
    }
}

enum CoachAIService {
    private static let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    static func answer(
        question: String,
        snapshot: CoachPromptSnapshot,
        history: [CoachTranscriptMessage],
        fallback: String
    ) async -> String {
        let defaults = UserDefaults.standard
        let isEnabled = defaults.bool(forKey: "coachAIEnabled")
        let model = defaults.string(forKey: "coachAIModel")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedModel = model?.isEmpty == false ? model! : CoachAIResponseMode.balanced.model

        guard isEnabled, let apiKey = CoachAIKeychain.readAPIKey(), apiKey.isEmpty == false else {
            return fallback
        }

        do {
            return try await requestOpenAIAnswer(
                question: question,
                snapshot: snapshot,
                history: history,
                apiKey: apiKey,
                model: selectedModel
            )
        } catch {
            return "AI is unavailable right now, so I used the local coach instead.\n\n\(fallback)"
        }
    }

    private static func requestOpenAIAnswer(
        question: String,
        snapshot: CoachPromptSnapshot,
        history: [CoachTranscriptMessage],
        apiKey: String,
        model: String
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let input = """
        App context:
        \(snapshot.promptText)

        Recent conversation:
        \(history.map { "\($0.role.capitalized): \($0.content)" }.joined(separator: "\n"))

        User question:
        \(question)
        """

        let responseMode = CoachAIResponseMode.mode(for: model)
        let body = OpenAIResponsesRequest(
            model: model,
            instructions: """
            You are the Ript Coach inside a personal triathlon, physique, discipline, meals, and journaling app.
            Use the supplied app context as source of truth.
            Give concise, practical guidance that protects triathlon performance while supporting getting lean and building visible abs.
            Prefer specific next actions over generic motivation.
            Do not invent completed workouts, meals, body metrics, or journal details.
            If injury, illness, chest pain, dizziness, or medical risk appears, advise the user to stop and seek qualified medical help.
            Write like a text message, not an article.
            Plain text only. Do not use Markdown formatting, headings, bold, italics, tables, code blocks, numbered lists, or bullet lists.
            Do not include Markdown characters such as ###, **, __, backticks, or leading bullet symbols.
            \(responseMode.responseGuidance)
            """,
            input: input,
            maxOutputTokens: responseMode.maxOutputTokens
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            throw CoachAIError.badStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
        if let outputText = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines), outputText.isEmpty == false {
            return outputText
        }

        let nestedText = decoded.output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let nestedText, nestedText.isEmpty == false else {
            throw CoachAIError.emptyResponse
        }

        return nestedText
    }
}

private struct OpenAIResponsesRequest: Encodable {
    let model: String
    let instructions: String
    let input: String
    let maxOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case instructions
        case input
        case maxOutputTokens = "max_output_tokens"
    }
}

private struct OpenAIResponsesResponse: Decodable {
    let outputText: String?
    let output: [OpenAIOutputItem]?

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }
}

private struct OpenAIOutputItem: Decodable {
    let content: [OpenAIOutputContent]?
}

private struct OpenAIOutputContent: Decodable {
    let text: String?
}

private enum CoachAIError: Error {
    case badStatus(Int)
    case emptyResponse
}
