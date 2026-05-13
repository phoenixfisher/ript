import Foundation
import SwiftUI
import UserNotifications
import SwiftData
import Security

enum Haptics {
    static func success() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

struct NotificationScheduler {
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func scheduleDailyReminders() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let items: [(String, Int, Int)] = [
            ("Win the first 10 seconds.", 6, 0),
            ("Did you win today?", 22, 30)
        ]

        for (body, hour, minute) in items {
            let content = UNMutableNotificationContent()
            content.title = "Ript"
            content.body = body
            var date = DateComponents()
            date.hour = hour
            date.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            center.add(request)
        }
    }
}

enum CoachAIKeychain {
    private static let service = "ript.coach.ai"
    private static let account = "openai.api.key"

    static func readAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func saveAPIKey(_ apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, let data = trimmed.data(using: .utf8) else { return }

        deleteAPIKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }

    static var hasAPIKey: Bool {
        readAPIKey()?.isEmpty == false
    }
}

struct CoachTranscriptMessage {
    let role: String
    let content: String
}

struct CoachPromptSnapshot {
    let readiness: String
    let primarySummary: String
    let topPriorities: [String]
    let guardrails: [String]
    let workoutRows: [String]
    let mealRows: [String]
    let reflectionRows: [String]
    let weekRows: [String]

    var promptText: String {
        """
        Today Read: \(readiness)
        Primary Summary: \(primarySummary)

        Coach Brief:
        \(topPriorities.map { "- \($0)" }.joined(separator: "\n"))

        Recovery Guardrails:
        \(guardrails.map { "- \($0)" }.joined(separator: "\n"))

        Workout Context:
        \(workoutRows.map { "- \($0)" }.joined(separator: "\n"))

        Meals and Fuel Context:
        \(mealRows.map { "- \($0)" }.joined(separator: "\n"))

        Reflection Context:
        \(reflectionRows.map { "- \($0)" }.joined(separator: "\n"))

        Week Snapshot:
        \(weekRows.map { "- \($0)" }.joined(separator: "\n"))
        """
    }
}

enum CoachAIService {
    private static let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    static func answer(
        question: String,
        snapshot: CoachPromptSnapshot,
        history: [CoachTranscriptMessage],
        fallback: String
    ) async -> String {
        let defaults = UserDefaults.standard
        let isEnabled = defaults.bool(forKey: "coachAIEnabled")
        let model = defaults.string(forKey: "coachAIModel")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedModel = model?.isEmpty == false ? model! : "gpt-5.4-mini"

        guard isEnabled, let apiKey = CoachAIKeychain.readAPIKey(), apiKey.isEmpty == false else {
            return fallback
        }

        do {
            return try await requestOpenAIAnswer(
                question: question,
                snapshot: snapshot,
                history: history,
                apiKey: apiKey,
                model: selectedModel
            )
        } catch {
            return "AI is unavailable right now, so I used the local coach instead.\n\n\(fallback)"
        }
    }

    private static func requestOpenAIAnswer(
        question: String,
        snapshot: CoachPromptSnapshot,
        history: [CoachTranscriptMessage],
        apiKey: String,
        model: String
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let input = """
        App context:
        \(snapshot.promptText)

        Recent conversation:
        \(history.map { "\($0.role.capitalized): \($0.content)" }.joined(separator: "\n"))

        User question:
        \(question)
        """

        let body = OpenAIResponsesRequest(
            model: model,
            instructions: """
            You are the Ript Coach inside a personal triathlon, physique, discipline, meals, and journaling app.
            Use the supplied app context as source of truth.
            Give concise, practical guidance that protects triathlon performance while supporting getting lean and building visible abs.
            Prefer specific next actions over generic motivation.
            Do not invent completed workouts, meals, body metrics, or journal details.
            If injury, illness, chest pain, dizziness, or medical risk appears, advise the user to stop and seek qualified medical help.
            Keep answers to 2-5 short paragraphs or a compact bullet list.
            """,
            input: input
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            throw CoachAIError.badStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
        if let outputText = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines), outputText.isEmpty == false {
            return outputText
        }

        let nestedText = decoded.output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let nestedText, nestedText.isEmpty == false else {
            throw CoachAIError.emptyResponse
        }

        return nestedText
    }
}

private struct OpenAIResponsesRequest: Encodable {
    let model: String
    let instructions: String
    let input: String
}

private struct OpenAIResponsesResponse: Decodable {
    let outputText: String?
    let output: [OpenAIOutputItem]?

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }
}

private struct OpenAIOutputItem: Decodable {
    let content: [OpenAIOutputContent]?
}

private struct OpenAIOutputContent: Decodable {
    let text: String?
}

private enum CoachAIError: Error {
    case badStatus(Int)
    case emptyResponse
}

struct SampleDataSeeder {
    static func seed(context: ModelContext) {
        seedWorkoutLibrary(context: context)
        seedTrainingPlan(context: context)
        seedMeals(context: context)
        try? context.save()
    }

    private static func seedWorkoutLibrary(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        let existingNames = Set(existing.map(\.name))

        defaultWorkouts
            .filter { existingNames.contains($0.name) == false }
            .forEach { context.insert($0) }
    }

    private static var defaultWorkouts: [Workout] {
        [
            Workout(name: "Lower Abs/Core A", exercises: [
                Exercise(name: "Reverse Crunch", sets: 3, repsDescription: "12-15 reps"),
                Exercise(name: "Dead Bug", sets: 3, repsDescription: "8-10 each side"),
                Exercise(name: "Plank", sets: 3, repsDescription: "45-60s"),
                Exercise(name: "Side Plank", sets: 3, repsDescription: "30-45s each side")
            ]),
            Workout(name: "Lower Abs/Core B", exercises: [
                Exercise(name: "Hanging Knee Raise", sets: 3, repsDescription: "8-12 reps"),
                Exercise(name: "Hollow Body Hold", sets: 3, repsDescription: "20-40s"),
                Exercise(name: "Mountain Climbers", sets: 3, repsDescription: "30-40s"),
                Exercise(name: "Slow Bicycle Crunch", sets: 3, repsDescription: "12 each side")
            ]),
            Workout(name: "Strength A", exercises: [
                Exercise(name: "Goblet Squat or Leg Press", sets: 3, repsDescription: "8-10 reps"),
                Exercise(name: "DB Bench Press or Push-ups", sets: 3, repsDescription: "8-12 reps"),
                Exercise(name: "One-arm Row", sets: 3, repsDescription: "10 each side"),
                Exercise(name: "Romanian Deadlift", sets: 3, repsDescription: "8-10 reps"),
                Exercise(name: "Pallof Press", sets: 3, repsDescription: "10 each side")
            ]),
            Workout(name: "Strength B", exercises: [
                Exercise(name: "Split Squat or Step-up", sets: 3, repsDescription: "8 each side"),
                Exercise(name: "Overhead Press", sets: 3, repsDescription: "8-10 reps"),
                Exercise(name: "Lat Pulldown or Pull-ups", sets: 3, repsDescription: "8-12 reps"),
                Exercise(name: "Hip Thrust or Hamstring Curl", sets: 3, repsDescription: "10-12 reps"),
                Exercise(name: "Cable Crunch or Reverse Crunch", sets: 3, repsDescription: "12-15 reps")
            ]),
            Workout(name: "Quick Home Workout", exercises: [
                Exercise(name: "Push-ups", sets: 3, repsDescription: "10-20 reps"),
                Exercise(name: "Air Squats", sets: 3, repsDescription: "20 reps"),
                Exercise(name: "Mountain Climbers", sets: 3, repsDescription: "30s")
            ]),
            Workout(name: "Gym Push Day", exercises: [
                Exercise(name: "Bench Press", sets: 4, repsDescription: "5-8 reps"),
                Exercise(name: "Incline DB Press", sets: 3, repsDescription: "8-12 reps"),
                Exercise(name: "Tricep Pushdown", sets: 3, repsDescription: "10-15 reps")
            ]),
            Workout(name: "Gym Pull Day", exercises: [
                Exercise(name: "Deadlift", sets: 3, repsDescription: "3-5 reps"),
                Exercise(name: "Lat Pulldown", sets: 3, repsDescription: "8-12 reps"),
                Exercise(name: "DB Row", sets: 3, repsDescription: "8-12 reps")
            ])
        ]
    }

    private static func seedTrainingPlan(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<TrainingSession>())) ?? []
        guard existing.isEmpty else { return }

        triathlonPlan.forEach { context.insert($0) }
    }

    private static var triathlonPlan: [TrainingSession] {
        [
            session("Week 1", 5, 7, "Bike Intervals", "Start the build controlled.", [
                required(.bike, "Bike 60 min", "4x5 min hard with easy spinning between efforts."),
                optionalSegment(.run, "Optional brick run", "10 min easy off the bike if legs feel good."),
                optionalSegment(.mobility, "Mobility reset", "5-8 min hips, calves, hamstrings.")
            ]),
            session("Week 1", 5, 8, "Swim + Easy Run", "Technique first, then easy miles.", [
                required(.swim, "Swim 1500-2000", "Easy aerobic swim plus drills."),
                required(.run, "Run 3 mi easy", "Keep this conversational."),
                recommended(.core, "Lower Abs/Core A", "3 rounds: reverse crunch, dead bug, plank, side plank.")
            ]),
            session("Week 1", 5, 9, "Brick Endurance", "Practice running on bike legs.", [
                required(.brick, "Bike 90 min + Run 3 mi", "Steady bike into an easy brick run.")
            ]),
            session("Week 1", 5, 10, "Rest Day", "Abs are built by recovering too.", [
                required(.rest, "Full rest", "No endurance work. Walk and stretch only if it helps."),
                optionalSegment(.mobility, "Easy mobility", "10 min relaxed movement.")
            ]),

            session("Week 2", 5, 11, "Swim + Easy Run", "Build volume without forcing pace.", [
                required(.swim, "Swim 2000", "6x200 steady with relaxed form."),
                required(.run, "Run 3-4 mi easy", "Stay easy enough to recover for Tuesday."),
                recommended(.core, "Lower Abs/Core A", "10-15 min after the run."),
                optionalSegment(.strength, "Strength A", "30-40 min later in the day if energy is good.")
            ]),
            session("Week 2", 5, 12, "Bike Intervals + Brick", "Key intensity day. Protect the legs.", [
                required(.bike, "Bike 75 min", "5x4 min hard with easy recovery."),
                required(.run, "Run 2 mi brick", "Short and controlled off the bike."),
                optionalSegment(.mobility, "Mobility only", "5-8 min hips and calves. Skip strength today.")
            ]),
            session("Week 2", 5, 13, "Swim + Faster Finish Run", "Aerobic work with a sharper finish.", [
                required(.swim, "Swim 2200", "Smooth aerobic swim."),
                required(.run, "Run 5 mi", "Last 2 mi faster, controlled effort."),
                recommended(.core, "Lower Abs/Core B", "Keep it crisp. Stop before hip flexors take over.")
            ]),
            session("Week 2", 5, 14, "Tempo Bike", "Tempo ride plus efficient strength.", [
                required(.bike, "Bike 60 min tempo", "Steady pressure, not a max effort."),
                optionalSegment(.swim, "Optional swim 1500", "Easy technique if you want extra water time."),
                recommended(.strength, "Strength A", "30-40 min after bike or separate from it.")
            ]),
            session("Week 2", 5, 15, "Drill Swim + Easy Run", "Easy day with core consistency.", [
                required(.swim, "Swim 1500", "Drills and easy form work."),
                required(.run, "Run 3 mi easy", "Recovery pace."),
                recommended(.core, "Lower Abs/Core A", "10-15 min after the run.")
            ]),
            session("Week 2", 5, 16, "Long Brick", "Endurance priority. No lifting today.", [
                required(.brick, "Bike 2 hr + Run 4 mi", "Long steady brick. Fuel it.")
            ]),
            session("Week 2", 5, 17, "Rest Day", "Recover so the next week lands.", [
                required(.rest, "Full rest", "Skip strength unless you feel unusually fresh."),
                optionalSegment(.mobility, "Easy mobility", "10 min relaxed movement.")
            ]),

            session("Week 3", 5, 18, "Swim + Easy Run", "Volume with optional strength.", [
                required(.swim, "Swim 2500", "Steady aerobic swim."),
                required(.run, "Run 4 mi easy", "Low stress miles."),
                recommended(.core, "Lower Abs/Core A", "10-15 min after the run."),
                optionalSegment(.strength, "Strength B", "30 min, leave 2-3 reps in reserve.")
            ]),
            session("Week 3", 5, 19, "Bike Intervals + Brick", "Hard bike day. Keep extras light.", [
                required(.bike, "Bike 90 min", "6x3 min hard."),
                required(.run, "Run 2-3 mi brick", "Easy off the bike."),
                optionalSegment(.mobility, "Mobility only", "5-8 min hips and calves.")
            ]),
            session("Week 3", 5, 20, "Swim + Mile Repeats", "Quality run day.", [
                required(.swim, "Swim 2000", "Smooth aerobic swim."),
                required(.run, "Run 6 mi", "3x1 mi around 7:15 pace."),
                recommended(.core, "Lower Abs/Core B", "Short and controlled.")
            ]),
            session("Week 3", 5, 21, "Tempo Bike + Strength", "Strength after the endurance work.", [
                required(.bike, "Bike 75 min tempo", "Steady tempo ride."),
                recommended(.strength, "Strength B", "30-40 min, moderate load.")
            ]),
            session("Week 3", 5, 22, "Easy Swim + Recovery Run", "Definition work without fatigue.", [
                required(.swim, "Swim 1800 easy", "Recovery swim."),
                required(.run, "Run 3 mi recovery", "Very easy."),
                recommended(.core, "Lower Abs/Core A", "10-15 min.")
            ]),
            session("Week 3", 5, 23, "Long Brick", "Big endurance day.", [
                required(.brick, "Bike 2-2.5 hr + Run 5 mi", "Keep strength out of this day.")
            ]),
            session("Week 3", 5, 24, "Rest Day", "Bank the adaptation.", [
                required(.rest, "Full rest", "Walk, stretch, or do nothing."),
                optionalSegment(.mobility, "Easy mobility", "10 min relaxed movement.")
            ]),

            session("Week 4", 5, 25, "Swim + Easy Run", "Big week starts steady.", [
                required(.swim, "Swim 2800", "Long steady swim."),
                required(.run, "Run 4 mi easy", "Keep it easy."),
                recommended(.core, "Lower Abs/Core B", "10-15 min."),
                optionalSegment(.strength, "Strength A", "30 min only if legs feel good.")
            ]),
            session("Week 4", 5, 26, "Bike Intervals + Brick", "Hard endurance day.", [
                required(.bike, "Bike 90 min", "4x8 min hard."),
                required(.run, "Run 3 mi brick", "Controlled off the bike."),
                optionalSegment(.mobility, "Mobility only", "5-8 min.")
            ]),
            session("Week 4", 5, 27, "Swim + Tempo Run", "Run quality day.", [
                required(.swim, "Swim 2200", "Smooth aerobic swim."),
                required(.run, "Run 6-7 mi", "4 mi around 7:15-7:00 pace."),
                recommended(.core, "Lower Abs/Core A", "Short, controlled core.")
            ]),
            session("Week 4", 5, 28, "Tempo Bike + Strength", "Last heavier strength slot this week.", [
                required(.bike, "Bike 75 min tempo", "Steady tempo ride."),
                recommended(.strength, "Strength A", "30-40 min, no max effort.")
            ]),
            session("Week 4", 5, 29, "Easy Swim + Recovery Run", "Keep the physique habit alive.", [
                required(.swim, "Swim 2000 easy", "Easy swim."),
                required(.run, "Run 3 mi recovery", "Very easy."),
                recommended(.core, "Lower Abs/Core B", "10-12 min.")
            ]),
            session("Week 4", 5, 30, "Race Effort Brick", "Key confidence session.", [
                required(.brick, "Bike 2 hr + Run 6 mi", "Race effort brick. Fuel and pace carefully.")
            ]),
            session("Week 4", 5, 31, "Rest Day", "Do less today.", [
                required(.rest, "Full rest", "No strength today."),
                optionalSegment(.mobility, "Easy mobility", "10 min relaxed movement.")
            ]),

            session("Week 5", 6, 1, "Swim + Easy Run", "Controlled build before taper.", [
                required(.swim, "Swim 2500", "Steady swim."),
                required(.run, "Run 4 mi easy", "Easy aerobic run."),
                recommended(.core, "Lower Abs/Core A", "10-15 min."),
                optionalSegment(.strength, "Strength B", "30 min if recovered.")
            ]),
            session("Week 5", 6, 2, "Bike Intervals + Brick", "Hard bike day.", [
                required(.bike, "Bike 75 min", "5x5 min hard."),
                required(.run, "Run 3 mi brick", "Easy to moderate."),
                optionalSegment(.mobility, "Mobility only", "5-8 min.")
            ]),
            session("Week 5", 6, 3, "Swim + Race Pace Run", "Specific run work.", [
                required(.swim, "Swim 2000", "Smooth swim."),
                required(.run, "Run 5 mi", "3 mi at race pace."),
                recommended(.core, "Lower Abs/Core B", "10-12 min.")
            ]),
            session("Week 5", 6, 4, "Tempo Bike + Strength", "Final meaningful strength slot.", [
                required(.bike, "Bike 60 min tempo", "Steady tempo."),
                recommended(.strength, "Strength B", "30 min, moderate load.")
            ]),
            session("Week 5", 6, 5, "Easy Swim + Easy Run", "Stay fresh.", [
                required(.swim, "Swim 1500 easy", "Relaxed swim."),
                required(.run, "Run 3 mi easy", "Easy run."),
                recommended(.core, "Lower Abs/Core A", "10 min.")
            ]),
            session("Week 5", 6, 6, "Race Effort Brick", "Sharpen, do not bury yourself.", [
                required(.brick, "Bike 90 min + Run 4 mi", "Race effort brick.")
            ]),
            session("Week 5", 6, 7, "Rest Day", "Recover into taper.", [
                required(.rest, "Full rest", "No strength today."),
                optionalSegment(.mobility, "Easy mobility", "10 min relaxed movement.")
            ]),

            session("Week 6", 6, 8, "Swim + Easy Run", "Taper begins.", [
                required(.swim, "Swim 2000", "Smooth and relaxed."),
                required(.run, "Run 3 mi easy", "Easy run."),
                recommended(.core, "Lower Abs/Core A", "10 min, no soreness.")
            ]),
            session("Week 6", 6, 9, "Short Bursts + Brick", "Keep speed, reduce cost.", [
                required(.bike, "Bike 60 min", "Short bursts, plenty of easy spinning."),
                required(.run, "Run 2 mi brick", "Easy off the bike."),
                optionalSegment(.mobility, "Mobility only", "5-8 min.")
            ]),
            session("Week 6", 6, 10, "Swim + Race Pace Touch", "Short quality only.", [
                required(.swim, "Swim 1800", "Smooth swim."),
                required(.run, "Run 4 mi", "2 mi at race pace."),
                recommended(.core, "Lower Abs/Core B", "8-10 min, light.")
            ]),
            session("Week 6", 6, 11, "Easy Bike", "Freshness over fitness.", [
                required(.bike, "Bike 45 min easy", "Easy spin."),
                optionalSegment(.mobility, "Mobility + activation", "5-8 min. No heavy strength.")
            ]),
            session("Week 6", 6, 12, "Easy Swim", "Keep feel for the water.", [
                required(.swim, "Swim 1200 easy", "Relaxed technique swim."),
                optionalSegment(.core, "Light core activation", "One easy round only if you want it.")
            ]),
            session("Week 6", 6, 13, "Short Brick", "Practice transitions without fatigue.", [
                required(.brick, "Bike 60 min + Run 2 mi", "Short relaxed brick.")
            ]),
            session("Week 6", 6, 14, "Rest Day", "Let the work absorb.", [
                required(.rest, "Full rest", "No extra training."),
                optionalSegment(.mobility, "Easy mobility", "10 min relaxed movement.")
            ]),

            session("Race Week", 6, 15, "Swim + Easy Run", "Stay sharp, stay fresh.", [
                required(.swim, "Swim 1500", "Smooth swim."),
                required(.run, "Run 3 mi easy", "Easy run."),
                optionalSegment(.core, "Core activation", "5-8 min only, no soreness.")
            ]),
            session("Race Week", 6, 16, "Short Effort Bike", "Open the legs.", [
                required(.bike, "Bike 45 min", "Short efforts with full recovery."),
                optionalSegment(.mobility, "Mobility only", "5 min relaxed.")
            ]),
            session("Race Week", 6, 17, "Swim + Easy Run", "Keep rhythm.", [
                required(.swim, "Swim 1000", "Easy technique swim."),
                required(.run, "Run 2 mi easy", "Very easy.")
            ]),
            session("Race Week", 6, 18, "Easy Bike", "Do the minimum effective work.", [
                required(.bike, "Bike 30 min easy", "Easy spin."),
                optionalSegment(.mobility, "Mobility only", "5 min relaxed.")
            ]),
            session("Race Week", 6, 19, "Off or Very Light", "Freshness is the goal.", [
                required(.rest, "Off or very light", "Rest, short walk, or very easy spin only.")
            ]),
            session("Race Week", 6, 20, "Race Day", "Execute calmly.", [
                required(.brick, "Olympic triathlon", "Race day. No strength or core add-ons.")
            ])
        ]
    }

    private static func seedMeals(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<MealIdea>())) ?? []
        let existingByTitle = Dictionary(uniqueKeysWithValues: existing.map { ($0.title, $0) })

        defaultMeals.forEach { seed in
            if let meal = existingByTitle[seed.title] {
                apply(seed, to: meal)
            } else {
                context.insert(MealIdea(
                    title: seed.title,
                    category: seed.category,
                    proteinGrams: seed.proteinGrams,
                    prepMinutes: seed.prepMinutes,
                    goalTags: seed.goalTags,
                    ingredients: seed.ingredients,
                    steps: seed.steps,
                    bestTiming: seed.bestTiming,
                    notes: seed.notes
                ))
            }
        }
    }

    private static var defaultMeals: [MealSeed] {
        [
            MealSeed(
                title: "Greek yogurt + fruit",
                category: "Breakfast",
                proteinGrams: 30,
                prepMinutes: 5,
                goalTags: ["High Protein", "Lean", "Quick"],
                ingredients: ["Greek yogurt", "Berries or banana", "Granola or oats", "Honey", "Cinnamon"],
                steps: ["Add yogurt to a bowl.", "Top with fruit and a small handful of granola or oats.", "Add honey and cinnamon if you want more carbs."],
                bestTiming: "Breakfast or post-workout",
                notes: "Easy protein with enough carbs to recover without feeling heavy."
            ),
            MealSeed(
                title: "Eggs + toast",
                category: "Breakfast",
                proteinGrams: 28,
                prepMinutes: 10,
                goalTags: ["High Protein", "Lean"],
                ingredients: ["2-3 eggs", "Whole grain toast", "Spinach", "Fruit"],
                steps: ["Scramble or fry the eggs.", "Toast the bread.", "Add spinach and fruit on the side."],
                bestTiming: "Breakfast or easy training day",
                notes: "Good default breakfast when you do not need a huge carb load."
            ),
            MealSeed(
                title: "Protein oats",
                category: "Breakfast",
                proteinGrams: 35,
                prepMinutes: 8,
                goalTags: ["Pre-Workout", "Post-Workout", "High Carb"],
                ingredients: ["Oats", "Protein powder", "Banana", "Milk or water", "Peanut butter"],
                steps: ["Cook oats with milk or water.", "Stir in protein powder after cooking.", "Top with banana and a small spoon of peanut butter."],
                bestTiming: "60-90 min before hard bike/run or after training",
                notes: "Useful on interval, brick, and long training days."
            ),
            MealSeed(
                title: "Turkey sandwich",
                category: "Lunch",
                proteinGrams: 35,
                prepMinutes: 7,
                goalTags: ["High Protein", "Quick", "Pre-Workout"],
                ingredients: ["Whole grain bread", "Turkey", "Cheese or avocado", "Lettuce", "Tomato", "Mustard"],
                steps: ["Build the sandwich.", "Add fruit or pretzels if training is hard later.", "Keep sauce light if you want it leaner."],
                bestTiming: "Lunch or 2-3 hours before training",
                notes: "Simple, repeatable, and easy to adjust with extra carbs."
            ),
            MealSeed(
                title: "Chicken + rice",
                category: "Dinner",
                proteinGrams: 42,
                prepMinutes: 25,
                goalTags: ["Post-Workout", "High Protein", "High Carb"],
                ingredients: ["Chicken breast or thighs", "Rice", "Vegetables", "Soy sauce or salsa", "Olive oil"],
                steps: ["Cook chicken with seasoning.", "Make rice.", "Add vegetables and sauce.", "Use a larger rice serving after long or hard sessions."],
                bestTiming: "Post-workout lunch or dinner",
                notes: "The default recovery meal: protein, carbs, and easy portion control."
            ),
            MealSeed(
                title: "Protein shake",
                category: "Snacks",
                proteinGrams: 25,
                prepMinutes: 2,
                goalTags: ["Post-Workout", "Quick", "No-Cook"],
                ingredients: ["Protein powder", "Milk or water", "Banana optional"],
                steps: ["Shake protein with liquid.", "Add banana if you need carbs after training."],
                bestTiming: "Immediately after training or between meals",
                notes: "Use this when a full meal is not realistic right away."
            ),
            MealSeed(
                title: "Chicken rice bowl",
                category: "Lunch",
                proteinGrams: 45,
                prepMinutes: 20,
                goalTags: ["Post-Workout", "High Protein", "High Carb"],
                ingredients: ["Chicken", "Rice", "Black beans", "Salsa", "Greek yogurt", "Lettuce"],
                steps: ["Heat rice and chicken.", "Add beans, salsa, lettuce, and Greek yogurt.", "Scale rice up on hard training days."],
                bestTiming: "Post-workout lunch",
                notes: "Good after bike/run sessions when you need carbs but still want a lean meal."
            ),
            MealSeed(
                title: "Tuna rice cakes",
                category: "Lunch",
                proteinGrams: 32,
                prepMinutes: 6,
                goalTags: ["Lean", "High Protein", "Quick"],
                ingredients: ["Tuna packet", "Rice cakes", "Pickles", "Greek yogurt or light mayo", "Hot sauce"],
                steps: ["Mix tuna with Greek yogurt or light mayo.", "Top rice cakes.", "Add pickles and hot sauce."],
                bestTiming: "Light lunch or easy day meal",
                notes: "High protein, lower calorie, and fast."
            ),
            MealSeed(
                title: "Salmon + sweet potato",
                category: "Dinner",
                proteinGrams: 38,
                prepMinutes: 30,
                goalTags: ["Post-Workout", "Lean", "High Protein"],
                ingredients: ["Salmon", "Sweet potato", "Green vegetables", "Lemon", "Olive oil"],
                steps: ["Bake salmon and sweet potato.", "Steam or saute vegetables.", "Finish with lemon and a little olive oil."],
                bestTiming: "Dinner after moderate training",
                notes: "Great for recovery without relying on a huge portion."
            ),
            MealSeed(
                title: "Turkey chili",
                category: "Dinner",
                proteinGrams: 40,
                prepMinutes: 35,
                goalTags: ["High Protein", "Meal Prep", "Lean"],
                ingredients: ["Lean ground turkey", "Beans", "Tomatoes", "Chili spices", "Onion"],
                steps: ["Brown turkey with onion.", "Add beans, tomatoes, and spices.", "Simmer until thick."],
                bestTiming: "Dinner or meal prep",
                notes: "Good batch meal for discipline and consistency."
            ),
            MealSeed(
                title: "Banana + peanut butter toast",
                category: "Snacks",
                proteinGrams: 10,
                prepMinutes: 4,
                goalTags: ["Pre-Workout", "Quick", "High Carb"],
                ingredients: ["Toast", "Banana", "Peanut butter", "Honey optional"],
                steps: ["Toast bread.", "Add peanut butter and banana.", "Use honey before long sessions if needed."],
                bestTiming: "30-90 min before training",
                notes: "Small enough before workouts, useful before bikes and runs."
            ),
            MealSeed(
                title: "Cottage cheese bowl",
                category: "Snacks",
                proteinGrams: 28,
                prepMinutes: 3,
                goalTags: ["High Protein", "Lean", "No-Cook"],
                ingredients: ["Cottage cheese", "Berries", "Cinnamon", "Granola optional"],
                steps: ["Add cottage cheese to a bowl.", "Top with berries and cinnamon.", "Add granola if you need more carbs."],
                bestTiming: "Snack or before bed",
                notes: "Easy protein when you are trying to stay lean."
            ),
            MealSeed(
                title: "Electrolyte carb bottle",
                category: "Snacks",
                proteinGrams: 0,
                prepMinutes: 2,
                goalTags: ["Pre-Workout", "Long Ride", "High Carb"],
                ingredients: ["Water", "Electrolyte mix", "Carb powder or sports drink"],
                steps: ["Mix bottle before training.", "Sip during long bikes or bricks.", "Use more carbs when sessions pass 90 minutes."],
                bestTiming: "During long bike or brick sessions",
                notes: "This is performance fuel, not a meal. It protects training quality."
            )
        ]
    }

    private static func apply(_ seed: MealSeed, to meal: MealIdea) {
        meal.category = seed.category
        meal.proteinGrams = seed.proteinGrams
        meal.prepMinutes = seed.prepMinutes
        meal.goalTags = seed.goalTags
        meal.ingredients = seed.ingredients
        meal.steps = seed.steps
        meal.bestTiming = seed.bestTiming
        meal.notes = seed.notes
    }

    private struct MealSeed {
        let title: String
        let category: String
        let proteinGrams: Int
        let prepMinutes: Int
        let goalTags: [String]
        let ingredients: [String]
        let steps: [String]
        let bestTiming: String
        let notes: String
    }

    private static func session(_ week: String, _ month: Int, _ day: Int, _ title: String, _ focus: String, _ segments: [TrainingSegment]) -> TrainingSession {
        TrainingSession(
            date: planDate(month: month, day: day),
            weekLabel: week,
            title: title,
            focus: focus,
            segments: segments
        )
    }

    private static func required(_ kind: TrainingSegmentKind, _ title: String, _ detail: String) -> TrainingSegment {
        TrainingSegment(title: title, detail: detail, kind: kind, priority: .required)
    }

    private static func recommended(_ kind: TrainingSegmentKind, _ title: String, _ detail: String) -> TrainingSegment {
        TrainingSegment(title: title, detail: detail, kind: kind, priority: .recommended)
    }

    private static func optionalSegment(_ kind: TrainingSegmentKind, _ title: String, _ detail: String) -> TrainingSegment {
        TrainingSegment(title: title, detail: detail, kind: kind, priority: .optional)
    }

    private static func planDate(month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = month
        components.day = day
        let date = Calendar.current.date(from: components) ?? Date()
        return Calendar.current.startOfDay(for: date)
    }
}
