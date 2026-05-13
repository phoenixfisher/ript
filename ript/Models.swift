import Foundation
import SwiftData

// MARK: - HabitType
enum HabitType: String, Codable, CaseIterable, Identifiable {
    case proteinEveryMeal = "Protein every meal"
    case intentionalTreat = "One intentional treat"
    case coreOrWorkout = "Core or workout"
    case stoppedAtNotHungry = "Stopped eating at not hungry"
    case gotUpImmediately = "Got up immediately"

    var id: String { rawValue }

    var xpReward: Int {
        switch self {
        case .proteinEveryMeal: return 20
        case .intentionalTreat: return 10
        case .coreOrWorkout: return 30
        case .stoppedAtNotHungry: return 15
        case .gotUpImmediately: return 15
        }
    }
}

// MARK: - Level System
struct Level: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let requiredXP: Int
}

let defaultLevels: [Level] = [
    .init(id: 1, title: "Getting Started", requiredXP: 0),
    .init(id: 2, title: "Locked In", requiredXP: 200),
    .init(id: 3, title: "Discipline Builder", requiredXP: 600),
    .init(id: 4, title: "Shirt-Off Confidence", requiredXP: 1200)
]

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

// MARK: - Training Plan (SwiftData)
@Model
final class TrainingSession {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weekLabel: String
    var title: String
    var focus: String
    var segments: [TrainingSegment]
    var isCompleted: Bool
    var completedAt: Date?
    var effortRating: String?

    init(
        id: UUID = UUID(),
        date: Date,
        weekLabel: String,
        title: String,
        focus: String,
        segments: [TrainingSegment],
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        effortRating: String? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.weekLabel = weekLabel
        self.title = title
        self.focus = focus
        self.segments = segments
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.effortRating = effortRating
    }
}

struct TrainingSegment: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var detail: String
    var kind: TrainingSegmentKind
    var priority: TrainingSegmentPriority
    var isCompleted: Bool = false
}

enum TrainingSegmentKind: String, Codable, CaseIterable, Identifiable {
    case swim
    case bike
    case run
    case brick
    case core
    case strength
    case mobility
    case rest

    var id: String { rawValue }
}

enum TrainingSegmentPriority: String, Codable, CaseIterable, Identifiable {
    case required
    case recommended
    case optional

    var id: String { rawValue }
}

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

// MARK: - Body Metrics (SwiftData)
@Model
final class BodyMetric {
    @Attribute(.unique) var date: Date
    var weight: Double? // kg or lbs user choice later
    var waist: Double? // cm or inches
    var estBodyFat: Double? // % estimate

    init(date: Date = Calendar.current.startOfDay(for: Date()), weight: Double? = nil, waist: Double? = nil, estBodyFat: Double? = nil) {
        self.date = Calendar.current.startOfDay(for: date)
        self.weight = weight
        self.waist = waist
        self.estBodyFat = estBodyFat
    }
}

// MARK: - Meal Idea (SwiftData)
@Model
final class MealIdea {
    @Attribute(.unique) var id: UUID
    var title: String
    var category: String // Breakfast, Lunch, Dinner, Snacks
    var proteinGrams: Int = 0
    var prepMinutes: Int = 0
    var goalTags: [String] = []
    var ingredients: [String] = []
    var steps: [String] = []
    var bestTiming: String = ""
    var notes: String = ""
    var isFavorite: Bool = false

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        proteinGrams: Int = 0,
        prepMinutes: Int = 0,
        goalTags: [String] = [],
        ingredients: [String] = [],
        steps: [String] = [],
        bestTiming: String = "",
        notes: String = "",
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.proteinGrams = proteinGrams
        self.prepMinutes = prepMinutes
        self.goalTags = goalTags
        self.ingredients = ingredients
        self.steps = steps
        self.bestTiming = bestTiming
        self.notes = notes
        self.isFavorite = isFavorite
    }
}

// MARK: - Badge (SwiftData)
@Model
final class Badge {
    @Attribute(.unique) var id: UUID
    var name: String
    var detail: String
    var unlockedOn: Date?

    init(id: UUID = UUID(), name: String, detail: String, unlockedOn: Date? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
        self.unlockedOn = unlockedOn
    }
}

// MARK: - Coach Chat (SwiftData)
@Model
final class CoachMessage {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var role: String
    var content: String

    init(id: UUID = UUID(), createdAt: Date = Date(), role: String, content: String) {
        self.id = id
        self.createdAt = createdAt
        self.role = role
        self.content = content
    }
}
