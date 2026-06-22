import Foundation
import SwiftData

struct HealthWorkoutValue: Identifiable, Hashable {
    var id: String { healthKitID }

    let healthKitID: String
    let startDate: Date
    let endDate: Date
    let activityIdentifier: String
    let activityName: String
    let kindRawValue: String?
    let durationMinutes: Int
    let distanceMeters: Double?
    let activeEnergyKilocalories: Double?
    let sourceName: String
}

@Model
final class HealthWorkout {
    @Attribute(.unique) var healthKitID: String
    var startDate: Date
    var endDate: Date
    var activityIdentifier: String
    var activityName: String
    var kindRawValue: String?
    var durationMinutes: Int
    var distanceMeters: Double?
    var activeEnergyKilocalories: Double?
    var sourceName: String
    var matchedTrainingSessionID: String?
    var updatedAt: Date

    init(
        healthKitID: String,
        startDate: Date,
        endDate: Date,
        activityIdentifier: String,
        activityName: String,
        kindRawValue: String? = nil,
        durationMinutes: Int,
        distanceMeters: Double? = nil,
        activeEnergyKilocalories: Double? = nil,
        sourceName: String,
        matchedTrainingSessionID: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.healthKitID = healthKitID
        self.startDate = startDate
        self.endDate = endDate
        self.activityIdentifier = activityIdentifier
        self.activityName = activityName
        self.kindRawValue = kindRawValue
        self.durationMinutes = durationMinutes
        self.distanceMeters = distanceMeters
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.sourceName = sourceName
        self.matchedTrainingSessionID = matchedTrainingSessionID
        self.updatedAt = updatedAt
    }

    convenience init(value: HealthWorkoutValue) {
        self.init(
            healthKitID: value.healthKitID,
            startDate: value.startDate,
            endDate: value.endDate,
            activityIdentifier: value.activityIdentifier,
            activityName: value.activityName,
            kindRawValue: value.kindRawValue,
            durationMinutes: value.durationMinutes,
            distanceMeters: value.distanceMeters,
            activeEnergyKilocalories: value.activeEnergyKilocalories,
            sourceName: value.sourceName
        )
    }

    func apply(_ value: HealthWorkoutValue) {
        startDate = value.startDate
        endDate = value.endDate
        activityIdentifier = value.activityIdentifier
        activityName = value.activityName
        kindRawValue = value.kindRawValue
        durationMinutes = value.durationMinutes
        distanceMeters = value.distanceMeters
        activeEnergyKilocalories = value.activeEnergyKilocalories
        sourceName = value.sourceName
        updatedAt = Date()
    }

    var trainingKind: TrainingSegmentKind? {
        guard let kindRawValue else { return nil }
        return TrainingSegmentKind(rawValue: kindRawValue)
    }

    var matchingTrainingKinds: Set<TrainingSegmentKind> {
        guard let trainingKind else { return [] }

        switch trainingKind {
        case .brick:
            return [.brick, .swim, .bike, .run]
        default:
            return [trainingKind]
        }
    }

    var title: String {
        activityName
    }

    var timeText: String {
        startDate.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    var durationText: String {
        "\(durationMinutes)m"
    }

    func distanceText(preferredUnit: String) -> String? {
        guard let distanceMeters, distanceMeters > 0 else { return nil }

        if preferredUnit == "Kilometers" {
            let kilometers = distanceMeters / 1000
            return kilometers.formatted(.number.precision(.fractionLength(kilometers < 10 ? 2 : 1))) + " km"
        }

        let miles = distanceMeters / 1609.344
        return miles.formatted(.number.precision(.fractionLength(miles < 10 ? 2 : 1))) + " mi"
    }

    var energyText: String? {
        guard let activeEnergyKilocalories, activeEnergyKilocalories > 0 else { return nil }
        return "\(Int(activeEnergyKilocalories.rounded())) kcal"
    }

    var summaryText: String {
        var parts = [durationText]
        if let energyText { parts.append(energyText) }
        if sourceName.isEmpty == false { parts.append(sourceName) }
        return parts.joined(separator: " | ")
    }
}

@MainActor
enum HealthWorkoutStore {
    static func upsert(_ workouts: [HealthWorkoutValue], in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<HealthWorkout>())
        var existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.healthKitID, $0) })

        for workout in workouts {
            if let existingWorkout = existingByID[workout.healthKitID] {
                existingWorkout.apply(workout)
            } else {
                let newWorkout = HealthWorkout(value: workout)
                context.insert(newWorkout)
                existingByID[workout.healthKitID] = newWorkout
            }
        }

        try context.save()
    }
}
