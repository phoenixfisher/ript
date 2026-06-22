import Foundation
import HealthKit

struct HealthImportPreferences: Hashable {
    var workouts: Bool
    var sleep: Bool
    var hrv: Bool
    var restingHeartRate: Bool
    var activeEnergy: Bool
    var bodyMetrics: Bool
}

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    private init() {}

    func requestAuthorization(preferences: HealthImportPreferences) async throws {
        guard Self.isAvailable else {
            throw HealthKitServiceError.notAvailable
        }

        let readTypes = Self.readTypes(for: preferences)
        guard readTypes.isEmpty == false else {
            throw HealthKitServiceError.noReadableTypesSelected
        }

        try await healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes)
    }

    func loadDailySummaries(daysBack: Int = 14, preferences: HealthImportPreferences) async throws -> [HealthDailySummaryValue] {
        guard Self.isAvailable else {
            throw HealthKitServiceError.notAvailable
        }

        let dayCount = max(daysBack, 1)
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
        let endDate = Date()
        var builders = makeBuilders(from: startDate, days: dayCount)

        if preferences.workouts {
            try await loadWorkouts(from: startDate, to: endDate, into: &builders)
        }

        if preferences.activeEnergy {
            try await loadDailyQuantityTotals(
                identifier: .activeEnergyBurned,
                unit: .kilocalorie(),
                from: startDate,
                to: endDate
            ) { date, value in
                builders[date]?.activeEnergyKilocalories = value
            }
        }

        if preferences.sleep {
            try await loadSleep(from: startDate, to: endDate, into: &builders)
        }

        if preferences.hrv {
            try await loadDailyQuantityAverages(
                identifier: .heartRateVariabilitySDNN,
                unit: .secondUnit(with: .milli),
                from: startDate,
                to: endDate
            ) { date, value in
                builders[date]?.hrvMilliseconds = value
            }
        }

        if preferences.restingHeartRate {
            try await loadDailyQuantityAverages(
                identifier: .restingHeartRate,
                unit: HKUnit.count().unitDivided(by: .minute()),
                from: startDate,
                to: endDate
            ) { date, value in
                builders[date]?.restingHeartRate = value
            }
        }

        if preferences.bodyMetrics {
            try await loadBodyMetrics(from: startDate, to: endDate, into: &builders)
        }

        return builders.values
            .compactMap { $0.build() }
            .sorted { $0.date > $1.date }
    }

    func loadHealthWorkouts(daysBack: Int = 14) async throws -> [HealthWorkoutValue] {
        guard Self.isAvailable else {
            throw HealthKitServiceError.notAvailable
        }

        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -(max(daysBack, 1) - 1), to: today) ?? today
        let endDate = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let samples = try await sampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate)

        return samples
            .compactMap { $0 as? HKWorkout }
            .map(Self.healthWorkoutValue)
            .sorted { $0.startDate > $1.startDate }
    }

    private static func readTypes(for preferences: HealthImportPreferences) -> Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        if preferences.workouts {
            types.insert(HKObjectType.workoutType())
        }

        if preferences.sleep,
           let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }

        if preferences.activeEnergy,
           let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergyType)
        }

        if preferences.hrv,
           let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrvType)
        }

        if preferences.restingHeartRate,
           let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHeartRateType)
        }

        if preferences.bodyMetrics {
            if let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
                types.insert(bodyMassType)
            }
            if let bodyFatType = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
                types.insert(bodyFatType)
            }
        }

        return types
    }

    private func makeBuilders(from startDate: Date, days: Int) -> [Date: HealthDailySummaryBuilder] {
        (0..<days).reduce(into: [:]) { result, offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return }
            let day = calendar.startOfDay(for: date)
            result[day] = HealthDailySummaryBuilder(date: day)
        }
    }

    private func loadWorkouts(
        from startDate: Date,
        to endDate: Date,
        into builders: inout [Date: HealthDailySummaryBuilder]
    ) async throws {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let samples = try await sampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate)
        let workouts = samples.compactMap { $0 as? HKWorkout }

        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startDate)
            guard builders[day] != nil else { continue }

            let minutes = Int((workout.duration / 60).rounded())
            builders[day]?.workoutCount += 1
            builders[day]?.workoutMinutes += minutes

            switch workout.workoutActivityType {
            case .swimming:
                builders[day]?.swimMinutes += minutes
            case .cycling:
                builders[day]?.bikeMinutes += minutes
            case .running:
                builders[day]?.runMinutes += minutes
            case .functionalStrengthTraining, .traditionalStrengthTraining:
                builders[day]?.strengthMinutes += minutes
            default:
                break
            }
        }
    }

    private func loadSleep(
        from startDate: Date,
        to endDate: Date,
        into builders: inout [Date: HealthDailySummaryBuilder]
    ) async throws {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitServiceError.missingType("sleep analysis")
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let samples = try await sampleQuery(sampleType: sleepType, predicate: predicate)
        let asleepValues = Self.asleepValues

        for sample in samples.compactMap({ $0 as? HKCategorySample }) where asleepValues.contains(sample.value) {
            addMinutes(sample.startDate, sample.endDate, into: &builders) { builder, minutes in
                builder.sleepMinutes = (builder.sleepMinutes ?? 0) + minutes
            }
        }
    }

    private func loadBodyMetrics(
        from startDate: Date,
        to endDate: Date,
        into builders: inout [Date: HealthDailySummaryBuilder]
    ) async throws {
        if let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            let samples = try await quantitySamples(type: bodyMassType, from: startDate, to: endDate)
            for sample in samples {
                let day = calendar.startOfDay(for: sample.startDate)
                builders[day]?.bodyMassKilograms = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            }
        }

        if let bodyFatType = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            let samples = try await quantitySamples(type: bodyFatType, from: startDate, to: endDate)
            for sample in samples {
                let day = calendar.startOfDay(for: sample.startDate)
                let rawPercent = sample.quantity.doubleValue(for: .percent())
                builders[day]?.bodyFatPercentage = rawPercent <= 1 ? rawPercent * 100 : rawPercent
            }
        }
    }

    private func quantitySamples(
        type: HKQuantityType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let samples = try await sampleQuery(sampleType: type, predicate: predicate)
        return samples.compactMap { $0 as? HKQuantitySample }
    }

    private func loadDailyQuantityTotals(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date,
        apply: @escaping (Date, Double) -> Void
    ) async throws {
        try await loadDailyQuantity(
            identifier: identifier,
            unit: unit,
            options: .cumulativeSum,
            from: startDate,
            to: endDate
        ) { statistics in
            statistics.sumQuantity()
        } apply: { date, value in
            apply(date, value)
        }
    }

    private func loadDailyQuantityAverages(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date,
        apply: @escaping (Date, Double) -> Void
    ) async throws {
        try await loadDailyQuantity(
            identifier: identifier,
            unit: unit,
            options: .discreteAverage,
            from: startDate,
            to: endDate
        ) { statistics in
            statistics.averageQuantity()
        } apply: { date, value in
            apply(date, value)
        }
    }

    private func loadDailyQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        from startDate: Date,
        to endDate: Date,
        quantity: @escaping (HKStatistics) -> HKQuantity?,
        apply: @escaping (Date, Double) -> Void
    ) async throws {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.missingType(identifier.rawValue)
        }

        let statistics = try await statisticsCollection(
            type: type,
            options: options,
            from: startDate,
            to: endDate
        )

        statistics.enumerateStatistics(from: startDate, to: endDate) { item, _ in
            guard let value = quantity(item)?.doubleValue(for: unit) else { return }
            apply(self.calendar.startOfDay(for: item.startDate), value)
        }
    }

    private func statisticsCollection(
        type: HKQuantityType,
        options: HKStatisticsOptions,
        from startDate: Date,
        to endDate: Date
    ) async throws -> HKStatisticsCollection {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            var interval = DateComponents()
            interval.day = 1

            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let collection else {
                    continuation.resume(throwing: HealthKitServiceError.emptyResult)
                    return
                }

                continuation.resume(returning: collection)
            }

            healthStore.execute(query)
        }
    }

    private func sampleQuery(sampleType: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: samples ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func addMinutes(
        _ rawStartDate: Date,
        _ rawEndDate: Date,
        into builders: inout [Date: HealthDailySummaryBuilder],
        apply: (inout HealthDailySummaryBuilder, Int) -> Void
    ) {
        guard rawEndDate > rawStartDate else { return }

        let firstDay = builders.keys.min() ?? calendar.startOfDay(for: rawStartDate)
        let lastDayEnd = calendar.date(byAdding: .day, value: 1, to: builders.keys.max() ?? firstDay) ?? rawEndDate
        var cursor = max(rawStartDate, firstDay)
        let endDate = min(rawEndDate, lastDayEnd)

        while cursor < endDate {
            let day = calendar.startOfDay(for: cursor)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? endDate
            let segmentEnd = min(nextDay, endDate)
            let minutes = max(0, Int((segmentEnd.timeIntervalSince(cursor) / 60).rounded()))

            if minutes > 0, var builder = builders[day] {
                apply(&builder, minutes)
                builders[day] = builder
            }

            cursor = segmentEnd
        }
    }

    private static func healthWorkoutValue(for workout: HKWorkout) -> HealthWorkoutValue {
        let activity = activityDescriptor(for: workout.workoutActivityType)
        let distanceMeters = workout.totalDistance?.doubleValue(for: .meter())
        let energyKilocalories = activeEnergyKilocalories(for: workout)

        return HealthWorkoutValue(
            healthKitID: workout.uuid.uuidString,
            startDate: workout.startDate,
            endDate: workout.endDate,
            activityIdentifier: activity.identifier,
            activityName: activity.name,
            kindRawValue: activity.kind?.rawValue,
            durationMinutes: Int((workout.duration / 60).rounded()),
            distanceMeters: distanceMeters,
            activeEnergyKilocalories: energyKilocalories,
            sourceName: workout.sourceRevision.source.name
        )
    }

    private static func activeEnergyKilocalories(for workout: HKWorkout) -> Double? {
        guard let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return nil
        }

        return workout.statistics(for: activeEnergyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
    }

    private static func activityDescriptor(for activityType: HKWorkoutActivityType) -> (identifier: String, name: String, kind: TrainingSegmentKind?) {
        switch activityType {
        case .swimming:
            return ("swimming", "Swim", .swim)
        case .cycling:
            return ("cycling", "Ride", .bike)
        case .running:
            return ("running", "Run", .run)
        case .swimBikeRun:
            return ("swimBikeRun", "Triathlon", .brick)
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return ("strength", "Strength", .strength)
        case .coreTraining:
            return ("coreTraining", "Core", .core)
        case .flexibility, .cooldown:
            return ("mobility", "Mobility", .mobility)
        case .walking:
            return ("walking", "Walk", nil)
        case .hiking:
            return ("hiking", "Hike", nil)
        case .highIntensityIntervalTraining:
            return ("hiit", "HIIT", .strength)
        default:
            return ("other", "Workout", nil)
        }
    }

    private static var asleepValues: Set<Int> {
        [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
    }
}

private struct HealthDailySummaryBuilder {
    var date: Date
    var workoutCount: Int = 0
    var workoutMinutes: Int = 0
    var swimMinutes: Int = 0
    var bikeMinutes: Int = 0
    var runMinutes: Int = 0
    var strengthMinutes: Int = 0
    var activeEnergyKilocalories: Double?
    var sleepMinutes: Int?
    var hrvMilliseconds: Double?
    var restingHeartRate: Double?
    var bodyMassKilograms: Double?
    var bodyFatPercentage: Double?

    func build() -> HealthDailySummaryValue? {
        guard hasData else { return nil }

        return HealthDailySummaryValue(
            date: date,
            workoutCount: workoutCount,
            workoutMinutes: workoutMinutes,
            swimMinutes: swimMinutes,
            bikeMinutes: bikeMinutes,
            runMinutes: runMinutes,
            strengthMinutes: strengthMinutes,
            activeEnergyKilocalories: activeEnergyKilocalories,
            sleepMinutes: sleepMinutes,
            hrvMilliseconds: hrvMilliseconds,
            restingHeartRate: restingHeartRate,
            bodyMassKilograms: bodyMassKilograms,
            bodyFatPercentage: bodyFatPercentage
        )
    }

    private var hasData: Bool {
        workoutCount > 0 ||
        activeEnergyKilocalories != nil ||
        sleepMinutes != nil ||
        hrvMilliseconds != nil ||
        restingHeartRate != nil ||
        bodyMassKilograms != nil ||
        bodyFatPercentage != nil
    }
}

private enum HealthKitServiceError: LocalizedError {
    case notAvailable
    case noReadableTypesSelected
    case missingType(String)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Health data is not available on this device."
        case .noReadableTypesSelected:
            return "Turn on at least one Apple Health data type before connecting."
        case .missingType(let name):
            return "Apple Health does not expose the requested type: \(name)."
        case .emptyResult:
            return "Apple Health returned no result for this query."
        }
    }
}
