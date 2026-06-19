import SwiftUI

struct CoachContext {
    var todaysSession: TrainingSession?
    var nextSession: TrainingSession?
    var todaysReflection: Reflection?
    var todaysDay: Day?
    var weekSessions: [TrainingSession]
    var fuelProfile: FuelProfile
    var mealPlan: SuggestedMealPlan

    var activeSession: TrainingSession? {
        todaysSession ?? nextSession
    }

    var promptSnapshot: CoachPromptSnapshot {
        CoachPromptSnapshot(
            readiness: readiness.title,
            primarySummary: primarySummary,
            topPriorities: topPriorities,
            guardrails: guardrailRows,
            workoutRows: workoutRows,
            mealRows: mealRows,
            reflectionRows: reflectionRows,
            weekRows: weekRows
        )
    }

    var readiness: CoachReadiness {
        let tags = Set(todaysReflection?.tags ?? [])
        let recoveryTags = Set(["Tired", "Stressed", "Flat", "Needed rest"])
        let mood = todaysReflection?.mood ?? 3

        if mood <= 2 || tags.isDisjoint(with: recoveryTags) == false {
            return .recover
        }

        if hasHardTraining || todaysReflection?.dayResult == "Mixed" || todaysReflection?.dayResult == "Missed" {
            return .hold
        }

        return .push
    }

    var primarySummary: String {
        activeSession?.requiredSummary ?? "No scheduled training found."
    }

    var topPriorities: [String] {
        switch readiness {
        case .push:
            return ["Do the required session", "Add recommended core or strength if it fits", "Keep protein steady"]
        case .hold:
            return ["Do required work first", "Skip optional strength if fatigue climbs", "Fuel before and after training"]
        case .recover:
            return ["Protect recovery", "Keep movement easy unless required", "Prioritize hydration and sleep"]
        }
    }

    var guardrailRows: [String] {
        switch readiness {
        case .push:
            return ["Warm up honestly before adding intensity", "Keep optional work efficient", "Stop add-ons before they threaten tomorrow"]
        case .hold:
            return ["Required training comes before extras", "Skip optional strength if legs feel heavy", "Use carbs around hard or long work"]
        case .recover:
            return ["No extra strength today", "Scale optional core to mobility or skip it", "Hydration and sleep beat more volume"]
        }
    }

    var hasHardTraining: Bool {
        guard let session = activeSession else { return false }
        return session.segments.contains { segment in
            segment.kind == .brick ||
            segment.detail.localizedCaseInsensitiveContains("hard") ||
            segment.detail.localizedCaseInsensitiveContains("tempo") ||
            segment.detail.localizedCaseInsensitiveContains("race pace") ||
            segment.title.localizedCaseInsensitiveContains("90 min") ||
            segment.title.localizedCaseInsensitiveContains("2 hr")
        }
    }

    var hasRecommendedStrength: Bool {
        activeSession?.segments.contains { $0.kind == .strength && $0.priority != .required } ?? false
    }

    var workoutRows: [String] {
        guard let session = activeSession else { return ["No workout scheduled."] }
        return [
            "\(session.date.formatted(date: .abbreviated, time: .omitted)): \(session.title)",
            session.focus,
            "Required: \(session.requiredSummary)",
            "\(session.completedSegmentCount)/\(session.segments.count) items checked"
        ]
    }

    var mealRows: [String] {
        let planned = mealPlan.items.map { item in
            "\(item.title): \(item.meal?.title ?? item.fallbackTitle)"
        }

        return ["Fuel read: \(fuelProfile.title)"] + planned
    }

    var reflectionRows: [String] {
        guard let reflection = todaysReflection else {
            return ["No journal logged today."]
        }

        var rows = [
            "Mood: \(reflection.mood)/5",
            "Result: \(reflection.dayResult)"
        ]

        if reflection.win.isEmpty == false { rows.append("Win: \(reflection.win)") }
        if reflection.obstacle.isEmpty == false { rows.append("Hard moment: \(reflection.obstacle)") }
        if reflection.tomorrowFocus.isEmpty == false { rows.append("Tomorrow: \(reflection.tomorrowFocus)") }
        if reflection.tags.isEmpty == false { rows.append("Tags: \(reflection.tags.joined(separator: ", "))") }
        return rows
    }

    var weekRows: [String] {
        let completed = weekSessions.filter(\.isCompleted).count
        let requiredSegments = weekSessions.flatMap(\.segments).filter { $0.priority == .required }
        let completedRequired = requiredSegments.filter(\.isCompleted).count

        return [
            "Sessions completed: \(completed)/\(weekSessions.count)",
            "Required items checked: \(completedRequired)/\(requiredSegments.count)",
            "Habit wins today: \(todaysDay?.completedHabits.count ?? 0)/\(HabitType.allCases.count)"
        ]
    }
}

enum CoachReadiness {
    case push
    case hold
    case recover

    var title: String {
        switch self {
        case .push: return "Push"
        case .hold: return "Hold"
        case .recover: return "Recover"
        }
    }

    var systemImage: String {
        switch self {
        case .push: return "bolt.fill"
        case .hold: return "pause.circle.fill"
        case .recover: return "leaf.fill"
        }
    }

    var tint: Color {
        switch self {
        case .push: return .green
        case .hold: return .yellow
        case .recover: return .blue
        }
    }
}

enum CoachBrain {
    static func openingBrief(for context: CoachContext) -> String {
        "Today is a \(context.readiness.title.lowercased()) day. \(context.primarySummary) \(context.topPriorities.joined(separator: " "))"
    }

    static func answer(_ question: String, context: CoachContext) -> String {
        let lower = question.lowercased()

        if lower.contains("strength") || lower.contains("core") || lower.contains("abs") {
            return strengthAnswer(context: context)
        }

        if lower.contains("eat") || lower.contains("meal") || lower.contains("fuel") || lower.contains("carb") {
            return mealAnswer(context: context)
        }

        if lower.contains("tired") || lower.contains("sore") || lower.contains("recover") || lower.contains("adjust") || lower.contains("legs") {
            return recoveryAnswer(context: context)
        }

        if lower.contains("tomorrow") || lower.contains("focus") {
            return tomorrowAnswer(context: context)
        }

        if lower.contains("week") || lower.contains("progress") || lower.contains("recap") {
            return weekAnswer(context: context)
        }

        return generalAnswer(context: context)
    }

    private static func strengthAnswer(context: CoachContext) -> String {
        switch context.readiness {
        case .recover:
            return "Skip strength today. Keep the required training easy if you do it, then use mobility or a short walk. Chasing abs while under-recovered usually costs more than it gives."
        case .hold:
            if context.hasRecommendedStrength {
                return "Strength is optional today. Do the required session first, then only lift if your legs feel normal. Keep it 30 minutes, moderate load, and leave reps in reserve."
            }
            return "I would not add strength today. Do the required work, keep core optional, and save lifting for an easier training day."
        case .push:
            return "You can add core or strength today. Keep it efficient: 10-15 minutes of lower abs/core, or 30-40 minutes full-body if it is already recommended in the plan."
        }
    }

    private static func mealAnswer(context: CoachContext) -> String {
        let mealLines = context.mealPlan.items.map { item in
            "\(item.title): \(item.meal?.title ?? item.fallbackTitle)"
        }
        return "Fuel read: \(context.fuelProfile.title). \(context.fuelProfile.guidance.joined(separator: " ")) Suggested plan: \(mealLines.joined(separator: "; "))."
    }

    private static func recoveryAnswer(context: CoachContext) -> String {
        switch context.readiness {
        case .recover:
            return "Make this a recovery-protecting day. Keep required work easy or scaled, skip optional strength, hydrate, and get the journal done tonight so tomorrow has a clear first win."
        case .hold:
            return "Hold the line: complete required work, avoid extra intensity, and use carbs around training. If soreness rises during warmup, drop optional add-ons first."
        case .push:
            return "You look clear to train, but still warm up honestly. If the first 10 minutes feel off, downgrade extras before touching the required session."
        }
    }

    private static func tomorrowAnswer(context: CoachContext) -> String {
        if let focus = context.todaysReflection?.tomorrowFocus, focus.isEmpty == false {
            return "Tomorrow's first win is already set: \(focus). Build the morning around that before adding anything else."
        }

        if let session = context.nextSession {
            return "Tomorrow or the next scheduled session is \(session.title): \(session.requiredSummary). Set one first win tonight, ideally fuel prep or getting the workout started on time."
        }

        return "Set a small first win for tomorrow: protein breakfast, start the workout on time, or get up immediately. Make it concrete enough to check off."
    }

    private static func weekAnswer(context: CoachContext) -> String {
        context.weekRows.joined(separator: " ")
    }

    private static func generalAnswer(context: CoachContext) -> String {
        switch context.readiness {
        case .push:
            return "Push, but keep it clean. Do the required session, add only the recommended extra work, and keep meals protein-forward with carbs around training."
        case .hold:
            return "Hold today. Required training first, optional add-ons second, and fuel the session. This is a day to execute, not prove anything."
        case .recover:
            return "Recover. Reduce optional work, keep food simple and high-protein, hydrate, and prioritize sleep. Consistency includes knowing when not to pile on."
        }
    }
}
