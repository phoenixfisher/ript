import Foundation
import SwiftData

@Model
final class CoachConversation {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var title: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        title: String = CoachConversationTitleBuilder.defaultTitle
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
    }
}

enum CoachConversationTitleBuilder {
    static let defaultTitle = "New Coach Chat"

    private static let stopWords: Set<String> = [
        "about", "after", "again", "before", "could", "doing", "from", "have", "help", "into",
        "just", "like", "need", "should", "that", "this", "today", "want", "what", "when",
        "where", "with", "would", "your"
    ]

    private static let keywordTitles: [(keywords: [String], title: String)] = [
        (["strength", "core", "abs", "lift", "lifting"], "Strength And Core Planning"),
        (["eat", "meal", "fuel", "carb", "protein"], "Fueling Around Today's Training"),
        (["tired", "sore", "recover", "recovery", "fatigue", "adjust", "legs"], "Recovery And Fatigue Check"),
        (["tomorrow", "focus", "next"], "Tomorrow Training Focus Plan"),
        (["week", "progress", "recap"], "Weekly Training Progress Recap"),
        (["swim", "bike", "run", "brick", "workout"], "Workout Execution And Pacing"),
        (["race", "taper"], "Race Week Readiness Check")
    ]

    static func title(for messages: [CoachMessage], adding prompt: String? = nil) -> String {
        let userText = messages
            .filter { $0.role == "user" }
            .map(\.content)
            .joined(separator: " ")

        let combinedText = [userText, prompt ?? ""]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard combinedText.isEmpty == false else { return defaultTitle }
        return title(for: combinedText)
    }

    static func title(for prompt: String) -> String {
        let lowercasedPrompt = prompt.lowercased()
        if let match = keywordTitles.first(where: { rule in
            rule.keywords.contains { lowercasedPrompt.contains($0) }
        }) {
            return match.title
        }

        var words = prompt
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.lowercased() }
            .filter { $0.count > 2 && stopWords.contains($0) == false }

        if words.isEmpty {
            words = ["coach", "chat", "plan", "check"]
        }

        let fillers = ["coach", "chat", "plan", "check"]
        for filler in fillers where words.count < 4 && words.contains(filler) == false {
            words.append(filler)
        }

        return words
            .prefix(7)
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
