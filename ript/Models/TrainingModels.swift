import Foundation
import SwiftData

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
