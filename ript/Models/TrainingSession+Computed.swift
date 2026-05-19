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

    var canComplete: Bool {
        let required = segments.filter { $0.priority == .required }
        guard required.isEmpty == false else { return true }
        return required.allSatisfy(\.isCompleted)
    }
}

// MARK: - Meals
