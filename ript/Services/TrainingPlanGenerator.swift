import Foundation

struct PlanSetupInput: Equatable {
    var goal: TrainingPlanGoal = .triathlon
    var planningAnchor: TrainingPlanAnchor = .startDate
    var startDate: Date = Date()
    var targetDate: Date = Calendar.current.date(byAdding: .weekOfYear, value: 6, to: Date()) ?? Date()
    var eventTarget: TrainingEventTarget = .baseBuild
    var outcome: TrainingGoalOutcome = .finishStrong
    var weekCount: Int = 6
    var trainingDaysPerWeek: Int = 5
    var dailyMinutes: Int = 60
    var currentWeeklyMinutes: Int = 240
    var experience: TrainingPlanExperience = .intermediate
    var readiness: TrainingPlanReadiness = .steady
    var preferredRestDay: TrainingPlanWeekday = .sunday
    var preferredLongSessionDay: TrainingPlanWeekday = .saturday
    var strengthPriority: TrainingStrengthPriority = .balanced
    var availableWeekdays: Set<TrainingPlanWeekday> = [.monday, .tuesday, .wednesday, .friday, .saturday]

    var effectiveTrainingDays: [TrainingPlanWeekday] {
        TrainingPlanWeekday.allCases.filter { weekday in
            availableWeekdays.contains(weekday) && weekday != preferredRestDay
        }
    }

    func resolvedStartDate(calendar: Calendar = .current) -> Date {
        switch planningAnchor {
        case .startDate:
            return calendar.startOfDay(for: startDate)
        case .targetDate:
            let target = calendar.startOfDay(for: targetDate)
            let daySpan = (weekCount.clamped(to: 4...24) * 7) - 1
            return calendar.date(byAdding: .day, value: -daySpan, to: target) ?? target
        }
    }
}

enum TrainingPlanAnchor: String, CaseIterable, Identifiable {
    case startDate
    case targetDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startDate:
            return "Start"
        case .targetDate:
            return "Event"
        }
    }
}

enum TrainingEventTarget: String, CaseIterable, Identifiable {
    case baseBuild
    case sprintTriathlon
    case olympicTriathlon
    case halfIronmanTriathlon
    case ironmanTriathlon
    case fiveK
    case tenK
    case halfMarathon
    case marathon
    case strengthBenchmark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .baseBuild:
            return "Base Build"
        case .sprintTriathlon:
            return "Sprint Triathlon"
        case .olympicTriathlon:
            return "Olympic Triathlon"
        case .halfIronmanTriathlon:
            return "Ironman 70.3"
        case .ironmanTriathlon:
            return "Ironman"
        case .fiveK:
            return "5K"
        case .tenK:
            return "10K"
        case .halfMarathon:
            return "Half Marathon"
        case .marathon:
            return "Marathon"
        case .strengthBenchmark:
            return "Strength Benchmark"
        }
    }

    var raceDayTitle: String {
        switch self {
        case .baseBuild:
            return "Assessment Day"
        case .strengthBenchmark:
            return "Benchmark Day"
        default:
            return "Race Day"
        }
    }

    var segmentKind: TrainingSegmentKind {
        switch self {
        case .sprintTriathlon, .olympicTriathlon, .halfIronmanTriathlon, .ironmanTriathlon:
            return .brick
        case .strengthBenchmark:
            return .strength
        case .baseBuild, .fiveK, .tenK, .halfMarathon, .marathon:
            return .run
        }
    }

    var eventDurationMinutes: Int {
        switch self {
        case .baseBuild:
            return 45
        case .sprintTriathlon:
            return 90
        case .olympicTriathlon:
            return 165
        case .halfIronmanTriathlon:
            return 360
        case .ironmanTriathlon:
            return 720
        case .fiveK:
            return 30
        case .tenK:
            return 55
        case .halfMarathon:
            return 120
        case .marathon:
            return 240
        case .strengthBenchmark:
            return 75
        }
    }

    var templateWeekCount: Int {
        switch self {
        case .baseBuild:
            return 6
        case .sprintTriathlon:
            return 10
        case .olympicTriathlon:
            return 12
        case .halfIronmanTriathlon:
            return 16
        case .ironmanTriathlon:
            return 24
        case .fiveK:
            return 6
        case .tenK:
            return 8
        case .halfMarathon:
            return 12
        case .marathon:
            return 16
        case .strengthBenchmark:
            return 8
        }
    }

    var distanceText: String {
        switch self {
        case .baseBuild:
            return "Fitness test"
        case .sprintTriathlon:
            return "750 / 20 / 5"
        case .olympicTriathlon:
            return "1.5 / 40 / 10"
        case .halfIronmanTriathlon:
            return "1.9 / 90 / 21"
        case .ironmanTriathlon:
            return "3.8 / 180 / 42"
        case .fiveK:
            return "5K"
        case .tenK:
            return "10K"
        case .halfMarathon:
            return "21.1K"
        case .marathon:
            return "42.2K"
        case .strengthBenchmark:
            return "Lift test"
        }
    }
}

enum TrainingGoalOutcome: String, CaseIterable, Identifiable {
    case finishStrong
    case personalBest
    case buildConsistency
    case peakStrength

    var id: String { rawValue }

    var title: String {
        switch self {
        case .finishStrong:
            return "Finish Strong"
        case .personalBest:
            return "Personal Best"
        case .buildConsistency:
            return "Consistency"
        case .peakStrength:
            return "Peak Strength"
        }
    }

    var loadMultiplier: Double {
        switch self {
        case .finishStrong:
            return 1.0
        case .personalBest:
            return 1.07
        case .buildConsistency:
            return 0.92
        case .peakStrength:
            return 1.04
        }
    }
}

enum TrainingPlanReadiness: String, CaseIterable, Identifiable {
    case recovery
    case steady
    case build

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recovery:
            return "Ease In"
        case .steady:
            return "Steady"
        case .build:
            return "Build"
        }
    }

    var loadMultiplier: Double {
        switch self {
        case .recovery:
            return 0.86
        case .steady:
            return 1.0
        case .build:
            return 1.08
        }
    }
}

enum TrainingPlanGoal: String, CaseIterable, Identifiable {
    case triathlon
    case running
    case strength
    case generalFitness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .triathlon:
            return "Triathlon"
        case .running:
            return "Running"
        case .strength:
            return "Strength"
        case .generalFitness:
            return "General Fitness"
        }
    }
}

enum TrainingPlanExperience: String, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner:
            return "Beginner"
        case .intermediate:
            return "Intermediate"
        case .advanced:
            return "Advanced"
        }
    }

    var loadMultiplier: Double {
        switch self {
        case .beginner:
            return 0.85
        case .intermediate:
            return 1.0
        case .advanced:
            return 1.15
        }
    }
}

enum TrainingStrengthPriority: String, CaseIterable, Identifiable {
    case light
    case balanced
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light:
            return "Light"
        case .balanced:
            return "Balanced"
        case .high:
            return "High"
        }
    }
}

enum TrainingPlanWeekday: Int, CaseIterable, Identifiable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    var id: Int { rawValue }
    var calendarWeekday: Int { rawValue }

    var title: String {
        switch self {
        case .monday:
            return "Monday"
        case .tuesday:
            return "Tuesday"
        case .wednesday:
            return "Wednesday"
        case .thursday:
            return "Thursday"
        case .friday:
            return "Friday"
        case .saturday:
            return "Saturday"
        case .sunday:
            return "Sunday"
        }
    }

    var shortTitle: String {
        switch self {
        case .monday:
            return "M"
        case .tuesday:
            return "T"
        case .wednesday:
            return "W"
        case .thursday:
            return "T"
        case .friday:
            return "F"
        case .saturday:
            return "S"
        case .sunday:
            return "S"
        }
    }
}

struct TrainingPlanGenerator {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func generate(input: PlanSetupInput) -> [TrainingSession] {
        let startDate = input.resolvedStartDate(calendar: calendar)
        let weekCount = input.weekCount.clamped(to: 4...24)
        let activeWeekdays = selectedWeekdays(input: input)

        guard activeWeekdays.count >= 3 else { return [] }

        var sessions: [TrainingSession] = []

        for weekIndex in 0..<weekCount {
            guard let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: startDate) else {
                continue
            }

            let weekLabel = "Week \(weekIndex + 1)"
            let weekDates = (0..<7).compactMap { offset in
                calendar.date(byAdding: .day, value: offset, to: weekStart)
            }
            let activeDates = weekDates.filter { date in
                activeWeekdays.contains(calendar.component(.weekday, from: date))
            }
            let trainingDates = orderedTrainingDates(activeDates, longWeekday: input.preferredLongSessionDay.calendarWeekday)

            for (slotIndex, date) in trainingDates.enumerated() {
                sessions.append(
                    session(
                        goal: input.goal,
                        date: date,
                        weekLabel: weekLabel,
                        slotIndex: slotIndex,
                        activeDayCount: trainingDates.count,
                        weekIndex: weekIndex,
                        weekCount: weekCount,
                        input: input
                    )
                )
            }

            if let restDate = restDate(in: weekDates, input: input, activeWeekdays: activeWeekdays) {
                sessions.append(restSession(date: restDate, weekLabel: weekLabel))
            }
        }

        if input.planningAnchor == .targetDate {
            let eventDate = calendar.startOfDay(for: input.targetDate)
            sessions.removeAll { calendar.isDate($0.date, inSameDayAs: eventDate) }
            sessions.append(eventSession(date: eventDate, weekLabel: "Week \(weekCount)", input: input))
        }

        return sessions.sorted { $0.date < $1.date }
    }

    private func selectedWeekdays(input: PlanSetupInput) -> Set<Int> {
        let selectedDays = input.effectiveTrainingDays.map(\.calendarWeekday)

        if selectedDays.count >= 3 {
            return Set(selectedDays.prefix(6))
        }

        return selectedWeekdays(
            restDay: input.preferredRestDay.calendarWeekday,
            count: input.trainingDaysPerWeek.clamped(to: 3...6)
        )
    }

    private func selectedWeekdays(restDay: Int, count: Int) -> Set<Int> {
        let baseDays: [Int]
        switch count {
        case 3:
            baseDays = [3, 5, 7]
        case 4:
            baseDays = [2, 4, 6, 7]
        case 5:
            baseDays = [2, 3, 4, 6, 7]
        default:
            baseDays = [2, 3, 4, 5, 6, 7]
        }

        var days = baseDays.filter { $0 != restDay }
        let fillDays = [2, 3, 4, 5, 6, 7, 1].filter { weekday in
            weekday != restDay && days.contains(weekday) == false
        }

        for weekday in fillDays where days.count < count {
            days.append(weekday)
        }

        return Set(days.prefix(count))
    }

    private func orderedTrainingDates(_ dates: [Date], longWeekday: Int) -> [Date] {
        var dates = dates.sorted()
        guard let longIndex = dates.firstIndex(where: { calendar.component(.weekday, from: $0) == longWeekday }) else {
            return dates
        }

        let longDate = dates.remove(at: longIndex)
        dates.append(longDate)
        return dates
    }

    private func restDate(in weekDates: [Date], input: PlanSetupInput, activeWeekdays: Set<Int>) -> Date? {
        if let preferred = weekDates.first(where: { calendar.component(.weekday, from: $0) == input.preferredRestDay.calendarWeekday }) {
            return preferred
        }

        return weekDates.first { date in
            activeWeekdays.contains(calendar.component(.weekday, from: date)) == false
        }
    }

    private func session(
        goal: TrainingPlanGoal,
        date: Date,
        weekLabel: String,
        slotIndex: Int,
        activeDayCount: Int,
        weekIndex: Int,
        weekCount: Int,
        input: PlanSetupInput
    ) -> TrainingSession {
        switch goal {
        case .triathlon:
            return triathlonSession(date: date, weekLabel: weekLabel, slotIndex: slotIndex, activeDayCount: activeDayCount, weekIndex: weekIndex, weekCount: weekCount, input: input)
        case .running:
            return runningSession(date: date, weekLabel: weekLabel, slotIndex: slotIndex, activeDayCount: activeDayCount, weekIndex: weekIndex, weekCount: weekCount, input: input)
        case .strength:
            return strengthSession(date: date, weekLabel: weekLabel, slotIndex: slotIndex, weekIndex: weekIndex, weekCount: weekCount, input: input)
        case .generalFitness:
            return generalFitnessSession(date: date, weekLabel: weekLabel, slotIndex: slotIndex, activeDayCount: activeDayCount, weekIndex: weekIndex, weekCount: weekCount, input: input)
        }
    }

    private func triathlonSession(
        date: Date,
        weekLabel: String,
        slotIndex: Int,
        activeDayCount: Int,
        weekIndex: Int,
        weekCount: Int,
        input: PlanSetupInput
    ) -> TrainingSession {
        if slotIndex == activeDayCount - 1 {
            let bikeMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 1.25)
            let runMinutes = max(10, duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.35))
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Long Brick",
                focus: "Practice steady bike-to-run pacing.",
                segments: [
                    required(.brick, "Bike \(bikeMinutes) min + Run \(runMinutes) min", "Keep the bike controlled and settle into the run without chasing pace.", durationMinutes: bikeMinutes + runMinutes, intensity: .steady),
                    optional(.mobility, "Mobility reset", "5-8 min for calves, hips, and hamstrings.", durationMinutes: 8, intensity: .recovery)
                ]
            )
        }

        switch slotIndex % 5 {
        case 0:
            let swimMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.75)
            let runMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.45)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Swim + Easy Run",
                focus: "Build aerobic volume without forcing pace.",
                segments: [
                    required(.swim, "Swim \(swimMinutes) min", "Smooth aerobic swim with easy technique focus.", durationMinutes: swimMinutes, intensity: .easy),
                    required(.run, "Run \(runMinutes) min easy", "Stay conversational and relaxed.", durationMinutes: runMinutes, intensity: .easy),
                    strengthAddon(input, kind: .core, title: "Core stability", detail: "8-12 min of planks, dead bugs, and side planks.", durationMinutes: 12, linkedWorkoutName: "Lower Abs/Core A")
                ]
            )
        case 1:
            let bikeMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 1.0)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Bike Intervals",
                focus: "Controlled intensity with clean recovery.",
                segments: [
                    required(.bike, "Bike \(bikeMinutes) min", "Include 4-6 hard efforts with easy spinning between repeats.", durationMinutes: bikeMinutes, intensity: .hard),
                    optional(.mobility, "Mobility only", "Skip heavy strength today if the legs feel loaded.", durationMinutes: 8, intensity: .recovery)
                ]
            )
        case 2:
            let swimMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.65)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Swim + Strength",
                focus: "Technique first, then durable strength.",
                segments: [
                    required(.swim, "Swim \(swimMinutes) min", "Drills plus relaxed aerobic work.", durationMinutes: swimMinutes, intensity: .easy),
                    strengthAddon(input, title: "Strength A", detail: "Squat or leg press, push, pull, hinge, and core. Leave reps in reserve.", durationMinutes: 35, linkedWorkoutName: "Strength A")
                ]
            )
        case 3:
            let runMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.85)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Tempo Run",
                focus: "Run quality without burying the week.",
                segments: [
                    required(.run, "Run \(runMinutes) min", "Middle portion steady and controlled, not all out.", durationMinutes: runMinutes, intensity: .steady),
                    recommended(.core, "Core finisher", "8-10 min controlled trunk work.", durationMinutes: 10, intensity: .easy, linkedWorkoutName: "Lower Abs/Core B")
                ]
            )
        default:
            let bikeMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.9)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Tempo Bike",
                focus: "Steady pressure and efficient form.",
                segments: [
                    required(.bike, "Bike \(bikeMinutes) min tempo", "Hold even effort and finish feeling controlled.", durationMinutes: bikeMinutes, intensity: .steady),
                    strengthAddon(input, title: "Strength B", detail: "Single-leg work, press, row, posterior chain, and core.", durationMinutes: 35, linkedWorkoutName: "Strength B")
                ]
            )
        }
    }

    private func runningSession(
        date: Date,
        weekLabel: String,
        slotIndex: Int,
        activeDayCount: Int,
        weekIndex: Int,
        weekCount: Int,
        input: PlanSetupInput
    ) -> TrainingSession {
        if slotIndex == activeDayCount - 1 {
            let minutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 1.2)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Long Run",
                focus: "Build endurance at an honest easy effort.",
                segments: [
                    required(.run, "Run \(minutes) min easy", "Keep the pace comfortable and fuel longer efforts.", durationMinutes: minutes, intensity: .easy),
                    optional(.mobility, "Mobility reset", "5-8 min calves, hips, and hamstrings.", durationMinutes: 8, intensity: .recovery)
                ]
            )
        }

        switch slotIndex % 4 {
        case 0:
            let minutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.75)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Easy Run + Core",
                focus: "Low-stress mileage and trunk control.",
                segments: [
                    required(.run, "Run \(minutes) min easy", "Keep this conversational.", durationMinutes: minutes, intensity: .easy),
                    recommended(.core, "Core stability", "8-12 min of planks, dead bugs, and side planks.", durationMinutes: 12, intensity: .easy, linkedWorkoutName: "Lower Abs/Core A")
                ]
            )
        case 1:
            let minutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.85)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Run Intervals",
                focus: "Speed with full control.",
                segments: [
                    required(.run, "Run \(minutes) min", "Include short hard repeats with easy recovery between efforts.", durationMinutes: minutes, intensity: .hard),
                    optional(.mobility, "Mobility only", "Keep lower legs and hips loose.", durationMinutes: 8, intensity: .recovery)
                ]
            )
        case 2:
            let minutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.7)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Strength Support",
                focus: "Build strength that protects the run.",
                segments: [
                    required(.strength, "Strength \(minutes) min", "Squat pattern, hinge, calf work, push, pull, and core.", durationMinutes: minutes, intensity: .steady, linkedWorkoutName: "Strength A"),
                    optional(.mobility, "Easy mobility", "5 min after lifting.", durationMinutes: 5, intensity: .recovery)
                ]
            )
        default:
            let minutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.9)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Tempo Run",
                focus: "Steady work below race effort.",
                segments: [
                    required(.run, "Run \(minutes) min", "Finish faster than you start, but stay controlled.", durationMinutes: minutes, intensity: .steady),
                    recommended(.core, "Core finisher", "8-10 min controlled work.", durationMinutes: 10, intensity: .easy, linkedWorkoutName: "Lower Abs/Core B")
                ]
            )
        }
    }

    private func strengthSession(
        date: Date,
        weekLabel: String,
        slotIndex: Int,
        weekIndex: Int,
        weekCount: Int,
        input: PlanSetupInput
    ) -> TrainingSession {
        switch slotIndex % 5 {
        case 0:
            let minutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.9)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Full Body Strength A",
                focus: "Train the big patterns with clean reps.",
                segments: [
                    required(.strength, "Strength \(minutes) min", "Squat, push, row, hinge, and loaded carry.", durationMinutes: minutes, intensity: .steady, linkedWorkoutName: "Strength A"),
                    recommended(.core, "Core finisher", "Anti-extension and side plank work.", durationMinutes: 10, intensity: .easy, linkedWorkoutName: "Lower Abs/Core A")
                ]
            )
        case 1:
            let coreMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.45)
            let conditioningMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.45)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Core + Conditioning",
                focus: "Build athletic conditioning without heavy joint stress.",
                segments: [
                    required(.core, "Core \(coreMinutes) min", "Dead bug, hollow hold, plank, side plank, and carries.", durationMinutes: coreMinutes, intensity: .easy, linkedWorkoutName: "Lower Abs/Core B"),
                    recommended(.run, "Conditioning \(conditioningMinutes) min", "Easy run, incline walk, bike, or row.", durationMinutes: conditioningMinutes, intensity: .easy)
                ]
            )
        case 2:
            let minutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.9)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Full Body Strength B",
                focus: "Single-leg strength and upper-body balance.",
                segments: [
                    required(.strength, "Strength \(minutes) min", "Split squat, press, pulldown, hip thrust, and trunk rotation.", durationMinutes: minutes, intensity: .steady, linkedWorkoutName: "Strength B"),
                    optional(.mobility, "Mobility reset", "5-8 min hips and shoulders.", durationMinutes: 8, intensity: .recovery)
                ]
            )
        case 3:
            let upperMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.7)
            let coreMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.3)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Upper + Core",
                focus: "Add volume without crushing the legs.",
                segments: [
                    required(.strength, "Upper strength \(upperMinutes) min", "Push, pull, shoulders, arms, and posture work.", durationMinutes: upperMinutes, intensity: .steady, linkedWorkoutName: "Gym Push Day"),
                    required(.core, "Core \(coreMinutes) min", "Controlled ab work without hip flexor takeover.", durationMinutes: coreMinutes, intensity: .easy, linkedWorkoutName: "Lower Abs/Core A")
                ]
            )
        default:
            let mobilityMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.35)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Mobility + Zone 2",
                focus: "Recover while keeping the habit alive.",
                segments: [
                    required(.mobility, "Mobility \(mobilityMinutes) min", "Move through hips, ankles, T-spine, and shoulders.", durationMinutes: mobilityMinutes, intensity: .recovery),
                    optional(.bike, "Easy cardio", "20-30 min relaxed zone 2 if you feel fresh.", durationMinutes: 25, intensity: .easy)
                ]
            )
        }
    }

    private func generalFitnessSession(
        date: Date,
        weekLabel: String,
        slotIndex: Int,
        activeDayCount: Int,
        weekIndex: Int,
        weekCount: Int,
        input: PlanSetupInput
    ) -> TrainingSession {
        if slotIndex == activeDayCount - 1 {
            let minutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 1.0)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Endurance Base",
                focus: "Build easy fitness and finish fresh.",
                segments: [
                    required(.run, "Easy cardio \(minutes) min", "Run, bike, swim, or incline walk at conversational effort.", durationMinutes: minutes, intensity: .easy),
                    optional(.mobility, "Mobility reset", "5-8 min relaxed movement.", durationMinutes: 8, intensity: .recovery)
                ]
            )
        }

        switch slotIndex % 4 {
        case 0:
            let minutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.8)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Full Body Strength",
                focus: "Build strength across the main patterns.",
                segments: [
                    required(.strength, "Strength \(minutes) min", "Squat, hinge, push, pull, and carry.", durationMinutes: minutes, intensity: .steady, linkedWorkoutName: "Strength A"),
                    recommended(.core, "Core stability", "8-10 min controlled trunk work.", durationMinutes: 10, intensity: .easy, linkedWorkoutName: "Lower Abs/Core A")
                ]
            )
        case 1:
            let minutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.75)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Conditioning",
                focus: "Work hard enough to improve, not enough to wreck tomorrow.",
                segments: [
                    required(.bike, "Conditioning \(minutes) min", "Bike, row, run, or circuit intervals with easy recovery.", durationMinutes: minutes, intensity: .hard),
                    optional(.mobility, "Cool down", "5 min easy movement.", durationMinutes: 5, intensity: .recovery)
                ]
            )
        case 2:
            let coreMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.45)
            let mobilityMinutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.3)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Core + Mobility",
                focus: "Move better and keep the midsection work consistent.",
                segments: [
                    required(.core, "Core \(coreMinutes) min", "Dead bugs, planks, carries, and anti-rotation.", durationMinutes: coreMinutes, intensity: .easy, linkedWorkoutName: "Lower Abs/Core B"),
                    required(.mobility, "Mobility \(mobilityMinutes) min", "Hips, ankles, hamstrings, T-spine, and shoulders.", durationMinutes: mobilityMinutes, intensity: .recovery)
                ]
            )
        default:
            let minutes = duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.75)
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Strength B",
                focus: "Second strength exposure with moderate volume.",
                segments: [
                    required(.strength, "Strength \(minutes) min", "Single-leg work, press, pull, posterior chain, and core.", durationMinutes: minutes, intensity: .steady, linkedWorkoutName: "Strength B"),
                    optional(.run, "Easy finisher", "10-15 min relaxed cardio if energy is good.", durationMinutes: 15, intensity: .easy)
                ]
            )
        }
    }

    private func restSession(date: Date, weekLabel: String) -> TrainingSession {
        TrainingSession(
            date: date,
            weekLabel: weekLabel,
            title: "Rest Day",
            focus: "Recover so the next sessions land.",
            segments: [
                required(.rest, "Full rest", "No hard training. Walk or stretch only if it helps.", durationMinutes: 0, intensity: .recovery),
                optional(.mobility, "Easy mobility", "5-10 min relaxed movement.", durationMinutes: 10, intensity: .recovery)
            ]
        )
    }

    private func eventSession(date: Date, weekLabel: String, input: PlanSetupInput) -> TrainingSession {
        let target = input.eventTarget
        return TrainingSession(
            date: date,
            weekLabel: weekLabel,
            title: target.raceDayTitle,
            focus: eventFocus(input: input),
            segments: [
                required(
                    target.segmentKind,
                    target.title,
                    eventDetail(input: input),
                    durationMinutes: target.eventDurationMinutes,
                    intensity: target == .baseBuild ? .steady : .race,
                    linkedWorkoutName: target == .strengthBenchmark ? "Strength A" : nil
                )
            ]
        )
    }

    private func eventFocus(input: PlanSetupInput) -> String {
        switch input.outcome {
        case .finishStrong:
            return "Execute calmly and finish with control."
        case .personalBest:
            return "Race with intent while protecting the back half."
        case .buildConsistency:
            return "Use the day as a controlled benchmark."
        case .peakStrength:
            return "Test the main lifts without chasing sloppy reps."
        }
    }

    private func eventDetail(input: PlanSetupInput) -> String {
        switch input.eventTarget {
        case .baseBuild:
            return "Controlled benchmark effort. Record how the pace and effort feel."
        case .strengthBenchmark:
            return "Warm up thoroughly, then test the planned lifts with clean technique."
        default:
            return "Race day. Keep the warmup familiar and execute the plan you rehearsed."
        }
    }

    private func duration(input: PlanSetupInput, weekIndex: Int, weekCount: Int, multiplier: Double) -> Int {
        let weekProgression = progressionMultiplier(weekIndex: weekIndex, weekCount: weekCount)
        let trainingDayCount = max(3, min(6, input.effectiveTrainingDays.count))
        let baselineDailyMinutes = Double(input.currentWeeklyMinutes.clamped(to: 90...1500)) / Double(trainingDayCount)
        let targetDailyMinutes = Double(input.dailyMinutes)
        let buildProgress = Double(weekIndex) / Double(max(weekCount - 1, 1))
        let blend = 0.45 + (buildProgress * 0.55)
        let plannedDailyMinutes = baselineDailyMinutes + ((targetDailyMinutes - baselineDailyMinutes) * blend)
        let rawMinutes = plannedDailyMinutes
            * multiplier
            * weekProgression
            * input.experience.loadMultiplier
            * input.readiness.loadMultiplier
            * input.outcome.loadMultiplier
        let roundedMinutes = Int((rawMinutes / 5).rounded()) * 5
        return max(10, roundedMinutes)
    }

    private func progressionMultiplier(weekIndex: Int, weekCount: Int) -> Double {
        var multiplier = 0.9 + (Double(weekIndex) * 0.05)

        if (weekIndex + 1) % 4 == 0 {
            multiplier *= 0.82
        }

        if weekIndex == weekCount - 1 && weekCount >= 6 {
            multiplier *= 0.72
        }

        return min(max(multiplier, 0.65), 1.25)
    }

    private func strengthAddon(
        _ input: PlanSetupInput,
        kind: TrainingSegmentKind = .strength,
        title: String,
        detail: String,
        durationMinutes: Int,
        linkedWorkoutName: String
    ) -> TrainingSegment {
        switch input.strengthPriority {
        case .light:
            return optional(kind, title, detail, durationMinutes: durationMinutes, intensity: .easy, linkedWorkoutName: linkedWorkoutName)
        case .balanced:
            return recommended(kind, title, detail, durationMinutes: durationMinutes, intensity: .steady, linkedWorkoutName: linkedWorkoutName)
        case .high:
            return required(kind, title, detail, durationMinutes: durationMinutes, intensity: .steady, linkedWorkoutName: linkedWorkoutName)
        }
    }

    private func required(
        _ kind: TrainingSegmentKind,
        _ title: String,
        _ detail: String,
        durationMinutes: Int? = nil,
        intensity: TrainingIntensity = .easy,
        linkedWorkoutName: String? = nil
    ) -> TrainingSegment {
        TrainingSegment(
            title: title,
            detail: detail,
            kind: kind,
            priority: .required,
            durationMinutes: durationMinutes,
            intensity: intensity,
            linkedWorkoutName: linkedWorkoutName
        )
    }

    private func recommended(
        _ kind: TrainingSegmentKind,
        _ title: String,
        _ detail: String,
        durationMinutes: Int? = nil,
        intensity: TrainingIntensity = .easy,
        linkedWorkoutName: String? = nil
    ) -> TrainingSegment {
        TrainingSegment(
            title: title,
            detail: detail,
            kind: kind,
            priority: .recommended,
            durationMinutes: durationMinutes,
            intensity: intensity,
            linkedWorkoutName: linkedWorkoutName
        )
    }

    private func optional(
        _ kind: TrainingSegmentKind,
        _ title: String,
        _ detail: String,
        durationMinutes: Int? = nil,
        intensity: TrainingIntensity = .easy,
        linkedWorkoutName: String? = nil
    ) -> TrainingSegment {
        TrainingSegment(
            title: title,
            detail: detail,
            kind: kind,
            priority: .optional,
            durationMinutes: durationMinutes,
            intensity: intensity,
            linkedWorkoutName: linkedWorkoutName
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
