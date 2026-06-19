import Foundation

extension TrainingSession {
    var completedSegmentCount: Int {
        segments.filter(\.isCompleted).count
    }

    var progress: Double {
        guard segments.isEmpty == false else { return 0 }
        return Double(completedSegmentCount) / Double(segments.count)
    }

    var requiredSummary: String {
        let required = segments
            .filter { $0.priority == .required }
            .map(\.title)

        return required.isEmpty ? "No required work" : required.joined(separator: " + ")
    }

    var scheduledMinutes: Int {
        segments.compactMap(\.durationMinutes).reduce(0, +)
    }

    var estimatedLoad: Int {
        segments.reduce(0) { $0 + $1.estimatedLoad }
    }

    var canComplete: Bool {
        let required = segments.filter { $0.priority == .required }
        guard required.isEmpty == false else { return true }
        return required.allSatisfy(\.isCompleted)
    }
}

struct TrainingWeekSummary: Identifiable, Equatable {
    let weekLabel: String
    let firstDate: Date
    let lastDate: Date
    let scheduledMinutes: Int
    let estimatedLoad: Int
    let hardSessionCount: Int
    let restDayCount: Int
    let minutesByKind: [TrainingSegmentKind: Int]

    var id: String {
        "\(weekLabel)-\(firstDate.timeIntervalSinceReferenceDate)"
    }

    var hoursText: String {
        let hours = Double(scheduledMinutes) / 60
        return hours.formatted(.number.precision(.fractionLength(hours < 10 ? 1 : 0))) + "h"
    }

    var splitText: String {
        let priority: [TrainingSegmentKind] = [.swim, .bike, .run, .brick, .strength, .core, .mobility]
        let parts = priority.compactMap { kind -> String? in
            guard let minutes = minutesByKind[kind], minutes > 0 else { return nil }
            return "\(kind.shortTitle) \(minutes)m"
        }

        return parts.prefix(3).joined(separator: " / ")
    }
}

extension Array where Element == TrainingSession {
    var trainingWeekSummaries: [TrainingWeekSummary] {
        Dictionary(grouping: self, by: \.weekLabel)
            .compactMap { weekLabel, sessions -> TrainingWeekSummary? in
                let sortedSessions = sessions.sorted { $0.date < $1.date }
                guard let firstDate = sortedSessions.first?.date,
                      let lastDate = sortedSessions.last?.date else { return nil }

                let minutesByKind = sortedSessions.reduce(into: [TrainingSegmentKind: Int]()) { result, session in
                    session.segments.forEach { segment in
                        guard let duration = segment.durationMinutes else { return }
                        result[segment.kind, default: 0] += duration
                    }
                }

                return TrainingWeekSummary(
                    weekLabel: weekLabel,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    scheduledMinutes: sortedSessions.reduce(0) { $0 + $1.scheduledMinutes },
                    estimatedLoad: sortedSessions.reduce(0) { $0 + $1.estimatedLoad },
                    hardSessionCount: sortedSessions.filter { session in
                        session.segments.contains { $0.intensity == .hard || $0.intensity == .race }
                    }.count,
                    restDayCount: sortedSessions.filter { session in
                        session.segments.contains { $0.kind == .rest && $0.priority == .required }
                    }.count,
                    minutesByKind: minutesByKind
                )
            }
            .sorted { $0.firstDate < $1.firstDate }
    }
}

// MARK: - Meals
