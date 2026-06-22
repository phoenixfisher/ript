import Foundation
import SwiftData

struct HealthDailySummaryValue: Identifiable, Hashable {
    var id: Date { date }

    let date: Date
    let workoutCount: Int
    let workoutMinutes: Int
    let swimMinutes: Int
    let bikeMinutes: Int
    let runMinutes: Int
    let strengthMinutes: Int
    let activeEnergyKilocalories: Double?
    let sleepMinutes: Int?
    let hrvMilliseconds: Double?
    let restingHeartRate: Double?
    let bodyMassKilograms: Double?
    let bodyFatPercentage: Double?
}

@Model
final class HealthDailySummary {
    @Attribute(.unique) var date: Date
    var workoutCount: Int
    var workoutMinutes: Int
    var swimMinutes: Int
    var bikeMinutes: Int
    var runMinutes: Int
    var strengthMinutes: Int
    var activeEnergyKilocalories: Double?
    var sleepMinutes: Int?
    var hrvMilliseconds: Double?
    var restingHeartRate: Double?
    var bodyMassKilograms: Double?
    var bodyFatPercentage: Double?
    var updatedAt: Date

    init(
        date: Date,
        workoutCount: Int = 0,
        workoutMinutes: Int = 0,
        swimMinutes: Int = 0,
        bikeMinutes: Int = 0,
        runMinutes: Int = 0,
        strengthMinutes: Int = 0,
        activeEnergyKilocalories: Double? = nil,
        sleepMinutes: Int? = nil,
        hrvMilliseconds: Double? = nil,
        restingHeartRate: Double? = nil,
        bodyMassKilograms: Double? = nil,
        bodyFatPercentage: Double? = nil,
        updatedAt: Date = Date()
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.workoutCount = workoutCount
        self.workoutMinutes = workoutMinutes
        self.swimMinutes = swimMinutes
        self.bikeMinutes = bikeMinutes
        self.runMinutes = runMinutes
        self.strengthMinutes = strengthMinutes
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.sleepMinutes = sleepMinutes
        self.hrvMilliseconds = hrvMilliseconds
        self.restingHeartRate = restingHeartRate
        self.bodyMassKilograms = bodyMassKilograms
        self.bodyFatPercentage = bodyFatPercentage
        self.updatedAt = updatedAt
    }

    convenience init(value: HealthDailySummaryValue) {
        self.init(date: value.date)
        apply(value)
    }

    func apply(_ value: HealthDailySummaryValue) {
        date = Calendar.current.startOfDay(for: value.date)
        workoutCount = value.workoutCount
        workoutMinutes = value.workoutMinutes
        swimMinutes = value.swimMinutes
        bikeMinutes = value.bikeMinutes
        runMinutes = value.runMinutes
        strengthMinutes = value.strengthMinutes
        activeEnergyKilocalories = value.activeEnergyKilocalories
        sleepMinutes = value.sleepMinutes
        hrvMilliseconds = value.hrvMilliseconds
        restingHeartRate = value.restingHeartRate
        bodyMassKilograms = value.bodyMassKilograms
        bodyFatPercentage = value.bodyFatPercentage
        updatedAt = Date()
    }

    var hasImportedData: Bool {
        workoutCount > 0 ||
        activeEnergyKilocalories != nil ||
        sleepMinutes != nil ||
        hrvMilliseconds != nil ||
        restingHeartRate != nil ||
        bodyMassKilograms != nil ||
        bodyFatPercentage != nil
    }

    var wellnessSummaryText: String {
        var parts: [String] = []

        if let sleepMinutes {
            parts.append("Sleep \(hoursText(minutes: sleepMinutes))")
        }

        if workoutMinutes > 0 {
            parts.append("Training \(workoutMinutes)m")
        }

        if let activeEnergyKilocalories {
            parts.append("Move \(Int(activeEnergyKilocalories.rounded())) kcal")
        }

        if let hrvMilliseconds {
            parts.append("HRV \(Int(hrvMilliseconds.rounded())) ms")
        }

        if let restingHeartRate {
            parts.append("RHR \(Int(restingHeartRate.rounded())) bpm")
        }

        return parts.isEmpty ? "No Health data imported today" : parts.prefix(3).joined(separator: " | ")
    }

    var coachRows: [String] {
        var rows: [String] = []

        if workoutCount > 0 {
            var workoutParts = ["\(workoutCount) workout\(workoutCount == 1 ? "" : "s")", "\(workoutMinutes) min"]
            if swimMinutes > 0 { workoutParts.append("swim \(swimMinutes)m") }
            if bikeMinutes > 0 { workoutParts.append("bike \(bikeMinutes)m") }
            if runMinutes > 0 { workoutParts.append("run \(runMinutes)m") }
            if strengthMinutes > 0 { workoutParts.append("strength \(strengthMinutes)m") }
            rows.append("Apple Health workouts: \(workoutParts.joined(separator: ", "))")
        }

        if let activeEnergyKilocalories {
            rows.append("Active energy: \(Int(activeEnergyKilocalories.rounded())) kcal")
        }

        if let sleepMinutes {
            rows.append("Sleep: \(hoursText(minutes: sleepMinutes))")
        }

        if let hrvMilliseconds {
            rows.append("HRV: \(Int(hrvMilliseconds.rounded())) ms")
        }

        if let restingHeartRate {
            rows.append("Resting heart rate: \(Int(restingHeartRate.rounded())) bpm")
        }

        if let bodyMassKilograms {
            rows.append("Body mass: \(bodyMassKilograms.formatted(.number.precision(.fractionLength(1)))) kg")
        }

        if let bodyFatPercentage {
            rows.append("Body fat: \(bodyFatPercentage.formatted(.number.precision(.fractionLength(1))))%")
        }

        return rows.isEmpty ? ["No Apple Health samples imported for today."] : rows
    }

    private func hoursText(minutes: Int) -> String {
        let hours = Double(minutes) / 60
        return hours.formatted(.number.precision(.fractionLength(1))) + "h"
    }
}

@MainActor
enum HealthSummaryStore {
    static func upsert(_ summaries: [HealthDailySummaryValue], in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<HealthDailySummary>())
        var existingByDate = Dictionary(uniqueKeysWithValues: existing.map { ($0.date, $0) })

        for summary in summaries {
            let day = Calendar.current.startOfDay(for: summary.date)
            if let existingSummary = existingByDate[day] {
                existingSummary.apply(summary)
            } else {
                let newSummary = HealthDailySummary(value: summary)
                context.insert(newSummary)
                existingByDate[day] = newSummary
            }
        }

        try context.save()
    }
}
