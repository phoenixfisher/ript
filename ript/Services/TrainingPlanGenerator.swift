import Foundation

struct PlanSetupInput: Equatable {
    var goal: TrainingPlanGoal = .triathlon
    var startDate: Date = Date()
    var weekCount: Int = 6
    var trainingDaysPerWeek: Int = 5
    var dailyMinutes: Int = 60
    var experience: TrainingPlanExperience = .intermediate
    var preferredRestDay: TrainingPlanWeekday = .sunday
    var strengthPriority: TrainingStrengthPriority = .balanced
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
}

struct TrainingPlanGenerator {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func generate(input: PlanSetupInput) -> [TrainingSession] {
        let startDate = calendar.startOfDay(for: input.startDate)
        let weekCount = input.weekCount.clamped(to: 4...12)
        let trainingDayCount = input.trainingDaysPerWeek.clamped(to: 3...6)
        let activeWeekdays = selectedWeekdays(
            restDay: input.preferredRestDay.calendarWeekday,
            count: trainingDayCount
        )

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

            for (slotIndex, date) in activeDates.enumerated() {
                sessions.append(
                    session(
                        goal: input.goal,
                        date: date,
                        weekLabel: weekLabel,
                        slotIndex: slotIndex,
                        activeDayCount: activeDates.count,
                        weekIndex: weekIndex,
                        weekCount: weekCount,
                        input: input
                    )
                )
            }

            if let restDate = weekDates.first(where: { calendar.component(.weekday, from: $0) == input.preferredRestDay.calendarWeekday }) {
                sessions.append(restSession(date: restDate, weekLabel: weekLabel))
            }
        }

        return sessions.sorted { $0.date < $1.date }
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
                    required(.brick, "Bike \(bikeMinutes) min + Run \(runMinutes) min", "Keep the bike controlled and settle into the run without chasing pace."),
                    optional(.mobility, "Mobility reset", "5-8 min for calves, hips, and hamstrings.")
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
                    required(.swim, "Swim \(swimMinutes) min", "Smooth aerobic swim with easy technique focus."),
                    required(.run, "Run \(runMinutes) min easy", "Stay conversational and relaxed."),
                    strengthAddon(input, title: "Core stability", detail: "8-12 min of planks, dead bugs, and side planks.")
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
                    required(.bike, "Bike \(bikeMinutes) min", "Include 4-6 hard efforts with easy spinning between repeats."),
                    optional(.mobility, "Mobility only", "Skip heavy strength today if the legs feel loaded.")
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
                    required(.swim, "Swim \(swimMinutes) min", "Drills plus relaxed aerobic work."),
                    strengthAddon(input, title: "Strength A", detail: "Squat or leg press, push, pull, hinge, and core. Leave reps in reserve.")
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
                    required(.run, "Run \(runMinutes) min", "Middle portion steady and controlled, not all out."),
                    recommended(.core, "Core finisher", "8-10 min controlled trunk work.")
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
                    required(.bike, "Bike \(bikeMinutes) min tempo", "Hold even effort and finish feeling controlled."),
                    strengthAddon(input, title: "Strength B", detail: "Single-leg work, press, row, posterior chain, and core.")
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
                    required(.run, "Run \(minutes) min easy", "Keep the pace comfortable and fuel longer efforts."),
                    optional(.mobility, "Mobility reset", "5-8 min calves, hips, and hamstrings.")
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
                    required(.run, "Run \(minutes) min easy", "Keep this conversational."),
                    recommended(.core, "Core stability", "8-12 min of planks, dead bugs, and side planks.")
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
                    required(.run, "Run \(minutes) min", "Include short hard repeats with easy recovery between efforts."),
                    optional(.mobility, "Mobility only", "Keep lower legs and hips loose.")
                ]
            )
        case 2:
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Strength Support",
                focus: "Build strength that protects the run.",
                segments: [
                    required(.strength, "Strength \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.7)) min", "Squat pattern, hinge, calf work, push, pull, and core."),
                    optional(.mobility, "Easy mobility", "5 min after lifting.")
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
                    required(.run, "Run \(minutes) min", "Finish faster than you start, but stay controlled."),
                    recommended(.core, "Core finisher", "8-10 min controlled work.")
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
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Full Body Strength A",
                focus: "Train the big patterns with clean reps.",
                segments: [
                    required(.strength, "Strength \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.9)) min", "Squat, push, row, hinge, and loaded carry."),
                    recommended(.core, "Core finisher", "Anti-extension and side plank work.")
                ]
            )
        case 1:
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Core + Conditioning",
                focus: "Build athletic conditioning without heavy joint stress.",
                segments: [
                    required(.core, "Core \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.45)) min", "Dead bug, hollow hold, plank, side plank, and carries."),
                    recommended(.run, "Conditioning \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.45)) min", "Easy run, incline walk, bike, or row.")
                ]
            )
        case 2:
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Full Body Strength B",
                focus: "Single-leg strength and upper-body balance.",
                segments: [
                    required(.strength, "Strength \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.9)) min", "Split squat, press, pulldown, hip thrust, and trunk rotation."),
                    optional(.mobility, "Mobility reset", "5-8 min hips and shoulders.")
                ]
            )
        case 3:
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Upper + Core",
                focus: "Add volume without crushing the legs.",
                segments: [
                    required(.strength, "Upper strength \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.7)) min", "Push, pull, shoulders, arms, and posture work."),
                    required(.core, "Core \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.3)) min", "Controlled ab work without hip flexor takeover.")
                ]
            )
        default:
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Mobility + Zone 2",
                focus: "Recover while keeping the habit alive.",
                segments: [
                    required(.mobility, "Mobility \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.35)) min", "Move through hips, ankles, T-spine, and shoulders."),
                    optional(.bike, "Easy cardio", "20-30 min relaxed zone 2 if you feel fresh.")
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
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Endurance Base",
                focus: "Build easy fitness and finish fresh.",
                segments: [
                    required(.run, "Easy cardio \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 1.0)) min", "Run, bike, swim, or incline walk at conversational effort."),
                    optional(.mobility, "Mobility reset", "5-8 min relaxed movement.")
                ]
            )
        }

        switch slotIndex % 4 {
        case 0:
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Full Body Strength",
                focus: "Build strength across the main patterns.",
                segments: [
                    required(.strength, "Strength \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.8)) min", "Squat, hinge, push, pull, and carry."),
                    recommended(.core, "Core stability", "8-10 min controlled trunk work.")
                ]
            )
        case 1:
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Conditioning",
                focus: "Work hard enough to improve, not enough to wreck tomorrow.",
                segments: [
                    required(.bike, "Conditioning \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.75)) min", "Bike, row, run, or circuit intervals with easy recovery."),
                    optional(.mobility, "Cool down", "5 min easy movement.")
                ]
            )
        case 2:
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Core + Mobility",
                focus: "Move better and keep the midsection work consistent.",
                segments: [
                    required(.core, "Core \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.45)) min", "Dead bugs, planks, carries, and anti-rotation."),
                    required(.mobility, "Mobility \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.3)) min", "Hips, ankles, hamstrings, T-spine, and shoulders.")
                ]
            )
        default:
            return TrainingSession(
                date: date,
                weekLabel: weekLabel,
                title: "Strength B",
                focus: "Second strength exposure with moderate volume.",
                segments: [
                    required(.strength, "Strength \(duration(input: input, weekIndex: weekIndex, weekCount: weekCount, multiplier: 0.75)) min", "Single-leg work, press, pull, posterior chain, and core."),
                    optional(.run, "Easy finisher", "10-15 min relaxed cardio if energy is good.")
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
                required(.rest, "Full rest", "No hard training. Walk or stretch only if it helps."),
                optional(.mobility, "Easy mobility", "5-10 min relaxed movement.")
            ]
        )
    }

    private func duration(input: PlanSetupInput, weekIndex: Int, weekCount: Int, multiplier: Double) -> Int {
        let weekProgression = progressionMultiplier(weekIndex: weekIndex, weekCount: weekCount)
        let rawMinutes = Double(input.dailyMinutes) * multiplier * weekProgression * input.experience.loadMultiplier
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

    private func strengthAddon(_ input: PlanSetupInput, title: String, detail: String) -> TrainingSegment {
        switch input.strengthPriority {
        case .light:
            return optional(.strength, title, detail)
        case .balanced:
            return recommended(.strength, title, detail)
        case .high:
            return required(.strength, title, detail)
        }
    }

    private func required(_ kind: TrainingSegmentKind, _ title: String, _ detail: String) -> TrainingSegment {
        TrainingSegment(title: title, detail: detail, kind: kind, priority: .required)
    }

    private func recommended(_ kind: TrainingSegmentKind, _ title: String, _ detail: String) -> TrainingSegment {
        TrainingSegment(title: title, detail: detail, kind: kind, priority: .recommended)
    }

    private func optional(_ kind: TrainingSegmentKind, _ title: String, _ detail: String) -> TrainingSegment {
        TrainingSegment(title: title, detail: detail, kind: kind, priority: .optional)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
