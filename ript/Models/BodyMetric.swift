import Foundation
import SwiftData

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
