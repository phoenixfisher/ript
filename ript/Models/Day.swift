import Foundation
import SwiftData

// MARK: - Day (SwiftData)
@Model
final class Day {
    @Attribute(.unique) var date: Date
    var completedHabits: [HabitType]
    var xpEarned: Int
    var perfectDay: Bool

    init(date: Date = Calendar.current.startOfDay(for: Date()), completedHabits: [HabitType] = [], xpEarned: Int = 0, perfectDay: Bool = false) {
        self.date = Calendar.current.startOfDay(for: date)
        self.completedHabits = completedHabits
        self.xpEarned = xpEarned
        self.perfectDay = perfectDay
    }
}
