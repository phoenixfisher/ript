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
