import Foundation
import SwiftData

// MARK: - Training Plan (SwiftData)
@Model
final class TrainingPlan {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var startDate: Date
    var endDate: Date
    var goalTitle: String
    var targetTitle: String?
    var weekCount: Int
    var scheduledMinutes: Int
    var estimatedLoad: Int

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        startDate: Date,
        endDate: Date,
        goalTitle: String,
        targetTitle: String? = nil,
        weekCount: Int,
        scheduledMinutes: Int,
        estimatedLoad: Int
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.startDate = startDate
        self.endDate = endDate
        self.goalTitle = goalTitle
        self.targetTitle = targetTitle
        self.weekCount = weekCount
        self.scheduledMinutes = scheduledMinutes
        self.estimatedLoad = estimatedLoad
    }
}

@Model
final class TrainingSession {
    @Attribute(.unique) var id: UUID
    var planID: UUID?
    var planName: String?
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
        planID: UUID? = nil,
        planName: String? = nil,
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
        self.planID = planID
        self.planName = planName
        self.date = date
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
    var durationMinutes: Int?
    var intensity: TrainingIntensity
    var estimatedLoad: Int
    var linkedWorkoutName: String?
    var isCompleted: Bool = false

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        kind: TrainingSegmentKind,
        priority: TrainingSegmentPriority,
        durationMinutes: Int? = nil,
        intensity: TrainingIntensity = .easy,
        estimatedLoad: Int? = nil,
        linkedWorkoutName: String? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.kind = kind
        self.priority = priority
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.estimatedLoad = estimatedLoad ?? TrainingSegment.loadEstimate(
            durationMinutes: durationMinutes,
            intensity: intensity,
            priority: priority
        )
        self.linkedWorkoutName = linkedWorkoutName
        self.isCompleted = isCompleted
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case kind
        case priority
        case durationMinutes
        case intensity
        case estimatedLoad
        case linkedWorkoutName
        case isCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedDuration = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        let decodedIntensity = try container.decodeIfPresent(TrainingIntensity.self, forKey: .intensity) ?? .easy
        let decodedPriority = try container.decode(TrainingSegmentPriority.self, forKey: .priority)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        detail = try container.decode(String.self, forKey: .detail)
        kind = try container.decode(TrainingSegmentKind.self, forKey: .kind)
        priority = decodedPriority
        durationMinutes = decodedDuration
        intensity = decodedIntensity
        estimatedLoad = try container.decodeIfPresent(Int.self, forKey: .estimatedLoad) ?? TrainingSegment.loadEstimate(
            durationMinutes: decodedDuration,
            intensity: decodedIntensity,
            priority: decodedPriority
        )
        linkedWorkoutName = try container.decodeIfPresent(String.self, forKey: .linkedWorkoutName)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(detail, forKey: .detail)
        try container.encode(kind, forKey: .kind)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(estimatedLoad, forKey: .estimatedLoad)
        try container.encodeIfPresent(linkedWorkoutName, forKey: .linkedWorkoutName)
        try container.encode(isCompleted, forKey: .isCompleted)
    }

    static func loadEstimate(
        durationMinutes: Int?,
        intensity: TrainingIntensity,
        priority: TrainingSegmentPriority
    ) -> Int {
        guard let durationMinutes else { return 0 }

        let priorityMultiplier: Double
        switch priority {
        case .required:
            priorityMultiplier = 1.0
        case .recommended:
            priorityMultiplier = 0.65
        case .optional:
            priorityMultiplier = 0.35
        }

        return Int((Double(durationMinutes) * intensity.loadFactor * priorityMultiplier).rounded())
    }
}

enum TrainingIntensity: String, Codable, CaseIterable, Identifiable {
    case recovery
    case easy
    case steady
    case hard
    case race

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recovery:
            return "Recovery"
        case .easy:
            return "Easy"
        case .steady:
            return "Steady"
        case .hard:
            return "Hard"
        case .race:
            return "Race"
        }
    }

    var loadFactor: Double {
        switch self {
        case .recovery:
            return 0.35
        case .easy:
            return 0.55
        case .steady:
            return 0.75
        case .hard:
            return 1.0
        case .race:
            return 1.15
        }
    }
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

    var shortTitle: String {
        switch self {
        case .swim:
            return "Swim"
        case .bike:
            return "Bike"
        case .run:
            return "Run"
        case .brick:
            return "Brick"
        case .core:
            return "Core"
        case .strength:
            return "Lift"
        case .mobility:
            return "Mob"
        case .rest:
            return "Rest"
        }
    }
}

enum TrainingSegmentPriority: String, Codable, CaseIterable, Identifiable {
    case required
    case recommended
    case optional

    var id: String { rawValue }
}
