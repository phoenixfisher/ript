import Foundation
import SwiftData

// MARK: - Reflection (SwiftData)
@Model
final class Reflection {
    @Attribute(.unique) var date: Date
    var didWin: Bool
    var mood: Int // 1..5 scale
    var note: String
    var dayResult: String = "Mixed"
    var prompt: String = "What worked today?"
    var tags: [String] = []
    var win: String = ""
    var obstacle: String = ""
    var tomorrowFocus: String = ""

    init(
        date: Date = Calendar.current.startOfDay(for: Date()),
        didWin: Bool,
        mood: Int,
        note: String,
        dayResult: String = "Mixed",
        prompt: String = "What worked today?",
        tags: [String] = [],
        win: String = "",
        obstacle: String = "",
        tomorrowFocus: String = ""
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.didWin = didWin
        self.mood = mood
        self.note = note
        self.dayResult = dayResult
        self.prompt = prompt
        self.tags = tags
        self.win = win
        self.obstacle = obstacle
        self.tomorrowFocus = tomorrowFocus
    }
}
