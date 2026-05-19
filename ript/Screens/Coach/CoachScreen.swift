import SwiftUI
import SwiftData

struct CoachScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CoachMessage.createdAt) private var messages: [CoachMessage]
    @Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]
    @Query(sort: \Day.date, order: .reverse) private var days: [Day]
    @Query(sort: \MealIdea.title) private var meals: [MealIdea]
    @State private var question: String = ""
    @State private var showCoachMenu: Bool = false
    @State private var isWaitingForAI: Bool = false

    private let suggestedQuestions = [
        "Should I do strength today?",
        "What should I eat before training?",
        "How should I adjust if I am tired?",
        "What is my focus tomorrow?"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                CoachBubble(role: "coach", content: CoachBrain.openingBrief(for: coachContext))
                                    .id("opening")
                            } else {
                                ForEach(messages) { message in
                                    CoachBubble(role: message.role, content: message.content)
                                        .id(message.id)
                                }
                            }

                            if isWaitingForAI {
                                CoachTypingBubble()
                                    .id("typing")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        scrollToLatest(with: proxy)
                    }
                    .onChange(of: isWaitingForAI) {
                        scrollToLatest(with: proxy)
                    }
                    .task {
                        scrollToLatest(with: proxy)
                    }
                }

                CoachComposerBar(question: $question, suggestions: suggestedQuestions) { prompt in
                    submit(prompt)
                }
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    showCoachMenu = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                }
                .accessibilityLabel("Coach Menu")
            }
            .sheet(isPresented: $showCoachMenu) {
                NavigationStack {
                    CoachMenuSheet(context: coachContext, hasMessages: messages.isEmpty == false) {
                        clearConversation()
                    }
                    .navigationTitle("Coach Menu")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        Button("Done") {
                            showCoachMenu = false
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var coachContext: CoachContext {
        let today = Calendar.current.startOfDay(for: Date())
        let todaysSession = trainingSessions.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let nextSession = trainingSessions.first { $0.date >= today }
        let todaysReflection = reflections.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let todaysDay = days.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let anchor = todaysSession ?? nextSession
        let weekSessions = anchor.map { session in
            trainingSessions.filter { $0.weekLabel == session.weekLabel }
        } ?? []
        let fuelProfile = FuelProfile.profile(for: todaysSession ?? nextSession)
        let mealPlan = SuggestedMealPlan.build(meals: meals, profile: fuelProfile, session: todaysSession ?? nextSession)

        return CoachContext(
            todaysSession: todaysSession,
            nextSession: nextSession,
            todaysReflection: todaysReflection,
            todaysDay: todaysDay,
            weekSessions: weekSessions,
            fuelProfile: fuelProfile,
            mealPlan: mealPlan
        )
    }

    private func submit(_ prompt: String? = nil) {
        let rawQuestion = (prompt ?? question).trimmingCharacters(in: .whitespacesAndNewlines)
        guard rawQuestion.isEmpty == false, isWaitingForAI == false else { return }

        question = ""
        context.insert(CoachMessage(role: "user", content: rawQuestion))
        try? context.save()
        Haptics.light()

        let contextSnapshot = coachContext.promptSnapshot
        let fallback = CoachBrain.answer(rawQuestion, context: coachContext)
        let history = messages.suffix(10).map { message in
            CoachTranscriptMessage(role: message.role, content: message.content)
        }

        isWaitingForAI = true
        Task {
            let answer = await CoachAIService.answer(
                question: rawQuestion,
                snapshot: contextSnapshot,
                history: history,
                fallback: fallback
            )

            context.insert(CoachMessage(role: "coach", content: answer))
            try? context.save()
            isWaitingForAI = false
            Haptics.light()
        }
    }

    private func clearConversation() {
        messages.forEach { context.delete($0) }
        try? context.save()
    }

    private func scrollToLatest(with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if isWaitingForAI {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            } else {
                proxy.scrollTo("opening", anchor: .bottom)
            }
        }
    }
}
struct CoachReadCard: View {
    var context: CoachContext

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Read")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(context.readiness.title)
                        .font(.largeTitle)
                        .bold()
                    Text(context.primarySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: context.readiness.systemImage)
                    .font(.title2)
                    .foregroundStyle(context.readiness.tint)
                    .frame(width: 38, height: 38)
                    .background(context.readiness.tint.opacity(0.14), in: Circle())
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(context.topPriorities, id: \.self) { priority in
                    Label(priority, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct AskCoachCard: View {
    @Binding var question: String
    var suggestions: [String]
    var onSubmit: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask Coach")
                .font(.headline)

            HStack(spacing: 10) {
                TextField("Ask about training, meals, recovery...", text: $question)
                    .submitLabel(.done)
                    .onSubmit { Keyboard.dismiss() }
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                Button {
                    onSubmit(nil)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(Color.green, in: Circle())
                }
                .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            onSubmit(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct CoachComposerBar: View {
    @Binding var question: String
    var suggestions: [String]
    var onSubmit: (String?) -> Void
    var sendInvalid: Bool {
        question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            onSubmit(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message Coach", text: $question)
                    .submitLabel(.done)
                    .onSubmit { Keyboard.dismiss() }
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))

                Button {
                    onSubmit(nil)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(Color.green.opacity(sendInvalid ? 0.3 : 1), in: Circle())
                }
                .disabled(sendInvalid)
            }
            .padding(.horizontal)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

struct CoachBubble: View {
    var role: String
    var content: String

    var body: some View {
        HStack {
            if role == "user" { Spacer(minLength: 36) }

            Text(content)
                .font(.subheadline)
                .foregroundStyle(role == "user" ? .black : .primary)
                .padding()
                .background(role == "user" ? Color.green : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

            if role != "user" { Spacer(minLength: 36) }
        }
    }
}

struct CoachTypingBubble: View {
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Coach is thinking")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

            Spacer(minLength: 36)
        }
    }
}

struct CoachMenuSheet: View {
    var context: CoachContext
    var hasMessages: Bool
    var onClearChat: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CoachReadCard(context: context)
                
                CoachMenuBlock(title: "Recovery Guardrails", systemImage: "shield.lefthalf.filled", rows: context.guardrailRows)

                CoachMenuBlock(title: "Coach Brief", systemImage: "sparkles", rows: context.topPriorities)

                CoachMenuBlock(title: "Weekly Snapshot", systemImage: "calendar", rows: context.weekRows)

                CoachContextPanel(context: context)
                
                CoachAISettingsCard()

                if hasMessages {
                    Button(role: .destructive) {
                        onClearChat()
                    } label: {
                        Label("Clear Chat", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct CoachMenuBlock: View {
    var title: String
    var systemImage: String
    var rows: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows, id: \.self) { row in
                    Label(row, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct CoachAISettingsCard: View {
    @AppStorage("coachAIEnabled") private var isAIEnabled: Bool = false
    @AppStorage("coachAIModel") private var model: String = "gpt-5.4-mini"
    @State private var apiKey: String = ""
    @State private var hasSavedKey: Bool = CoachAIKeychain.hasAPIKey

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $isAIEnabled)
                    .labelsHidden()
            }

            Text(hasSavedKey ? "OpenAI key saved. Coach will use AI when enabled." : "Add an OpenAI API key to use real AI responses.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Model", text: $model)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { Keyboard.dismiss() }
                .textFieldStyle(.roundedBorder)

            SecureField(hasSavedKey ? "Replace API key" : "OpenAI API key", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { Keyboard.dismiss() }
                .textFieldStyle(.roundedBorder)

            HStack {
                Button {
                    CoachAIKeychain.saveAPIKey(apiKey)
                    apiKey = ""
                    hasSavedKey = CoachAIKeychain.hasAPIKey
                    Haptics.success()
                } label: {
                    Label("Save Key", systemImage: "key.fill")
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                if hasSavedKey {
                    Button(role: .destructive) {
                        CoachAIKeychain.deleteAPIKey()
                        hasSavedKey = false
                        isAIEnabled = false
                        apiKey = ""
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct CoachContextPanel: View {
    var context: CoachContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Context")
                .font(.headline)

            DisclosureGroup("Workout") {
                CoachContextRows(rows: context.workoutRows)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

            DisclosureGroup("Meals & Fuel") {
                CoachContextRows(rows: context.mealRows)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

            DisclosureGroup("Reflect") {
                CoachContextRows(rows: context.reflectionRows)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

            DisclosureGroup("Week Snapshot") {
                CoachContextRows(rows: context.weekRows)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CoachContextRows: View {
    var rows: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                Text(row)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 8)
    }
}

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
