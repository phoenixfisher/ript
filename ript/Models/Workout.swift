import Foundation
import SwiftData

// MARK: - Workout (SwiftData)
@Model
final class Workout {
    @Attribute(.unique) var id: UUID
    var name: String
    var exercises: [Exercise]
    var lastCompleted: Date?

    init(id: UUID = UUID(), name: String, exercises: [Exercise], lastCompleted: Date? = nil) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.lastCompleted = lastCompleted
    }
}

struct Exercise: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var sets: Int
    var repsDescription: String
}
