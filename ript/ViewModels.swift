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

@MainActor
final class WorkoutTimerViewModel: ObservableObject {
    @Published var remaining: Int = 60
    @Published var isRunning: Bool = false
    private var timer: Timer?

    func start(seconds: Int = 60) {
        remaining = seconds
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self = self else { return }
            if self.remaining > 0 { self.remaining -= 1 } else { self.stop() }
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
}
