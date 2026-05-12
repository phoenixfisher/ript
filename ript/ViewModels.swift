import Foundation
import SwiftData
internal import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published var levels: [Level] = defaultLevels

    func level(for totalXP: Int) -> Level {
        var current = levels.first!
        for level in levels.sorted(by: { $0.requiredXP < $1.requiredXP }) {
            if totalXP >= level.requiredXP { current = level } else { break }
        }
        return current
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var dailyQuote: String = HomeViewModel.randomQuote()

    static func randomQuote() -> String {
        [
            "Win the first 10 seconds.",
            "Small wins. Big results.",
            "Show up. Then show off.",
            "Discipline beats motivation.",
            "Consistency compounds."
        ].randomElement()!
    }

    func resetQuote() { dailyQuote = Self.randomQuote() }
}
