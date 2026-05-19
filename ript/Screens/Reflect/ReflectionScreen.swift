import SwiftUI
import SwiftData

struct ReflectionScreen: View {
    @Environment(\.modelContext) private var context
    @Query(filter: { () -> Predicate<Reflection> in
        let todayStart = Calendar.current.startOfDay(for: Date())
        return #Predicate { $0.date == todayStart }
    }())
    private var todayArray: [Reflection]

    // Local UI state
    @State private var didWin: Bool = false
    @State private var mood: Int = 3
    @State private var dayResult: String = "Mixed"
    @State private var selectedPrompt: String = "What worked today?"
    @State private var selectedTags: [String] = []
    @State private var win: String = ""
    @State private var obstacle: String = ""
    @State private var tomorrowFocus: String = ""
    @State private var note: String = ""
    @State private var showSavedToast: Bool = false
    @State private var isDirty: Bool = false

    // For history listing
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]

    init() {}

    private var today: Reflection {
        if let r = todayArray.first { return r }
        let r = Reflection(didWin: false, mood: 3, note: "")
        context.insert(r)
        return r
    }

    private let noteLimit = 600
    private let shortFieldLimit = 120
    private let prompts = [
        "What worked today?",
        "What got in the way?",
        "Where did I show discipline?",
        "What do I want to repeat tomorrow?",
        "What did I learn about myself?"
    ]
    private let tagOptions = [
        "Disciplined",
        "Focused",
        "Proud",
        "Calm",
        "Tired",
        "Hungry",
        "Stressed",
        "Flat",
        "Resilient",
        "Needed rest"
    ]
    private let resultOptions = ["Won", "Mixed", "Missed"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    JournalSummaryCard(mood: mood, result: dayResult, tags: selectedTags)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mood")
                            .font(.headline)
                        MoodPicker(selectedMood: Binding(get: { mood }, set: { newValue in
                            mood = newValue
                            updateToday { $0.mood = newValue }
                        }))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Day Result")
                            .font(.headline)
                        HStack(spacing: 8) {
                            ForEach(resultOptions, id: \.self) { option in
                                JournalChoiceButton(title: option, isSelected: dayResult == option) {
                                    dayResult = option
                                    didWin = option == "Won"
                                    updateToday {
                                        $0.dayResult = option
                                        $0.didWin = option == "Won"
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Prompt Deck")
                            .font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(prompts, id: \.self) { prompt in
                                    JournalChip(title: prompt, isSelected: selectedPrompt == prompt) {
                                        selectedPrompt = prompt
                                        updateToday { $0.prompt = prompt }
                                    }
                                }
                            }
                        }
                    }

                    JournalTextBlock(
                        title: "Journal",
                        prompt: selectedPrompt,
                        text: Binding(get: { note }, set: { newValue in
                            let trimmed = String(newValue.prefix(noteLimit))
                            note = trimmed
                            updateToday { $0.note = trimmed }
                        }),
                        limit: noteLimit,
                        lineRange: 5...9
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Three Lines")
                            .font(.headline)

                        JournalTextBlock(
                            title: "Win",
                            prompt: "What is one thing you did right?",
                            text: Binding(get: { win }, set: { newValue in
                                let trimmed = String(newValue.prefix(shortFieldLimit))
                                win = trimmed
                                updateToday { $0.win = trimmed }
                            }),
                            limit: shortFieldLimit,
                            lineRange: 1...3
                        )

                        JournalTextBlock(
                            title: "Hard Moment",
                            prompt: "What tested you?",
                            text: Binding(get: { obstacle }, set: { newValue in
                                let trimmed = String(newValue.prefix(shortFieldLimit))
                                obstacle = trimmed
                                updateToday { $0.obstacle = trimmed }
                            }),
                            limit: shortFieldLimit,
                            lineRange: 1...3
                        )

                        JournalTextBlock(
                            title: "Tomorrow",
                            prompt: "What is the first thing to get right?",
                            text: Binding(get: { tomorrowFocus }, set: { newValue in
                                let trimmed = String(newValue.prefix(shortFieldLimit))
                                tomorrowFocus = trimmed
                                updateToday { $0.tomorrowFocus = trimmed }
                            }),
                            limit: shortFieldLimit,
                            lineRange: 1...3
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(tagOptions, id: \.self) { tag in
                                JournalChip(title: tag, isSelected: selectedTags.contains(tag)) {
                                    toggleTag(tag)
                                }
                            }
                        }
                    }

                    HStack {
                        Button(role: .destructive) {
                            resetToday()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }

                        Spacer()

                        Button {
                            save(force: true, showFeedback: true)
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isDirty)
                    }

                    if recentReflections.isEmpty == false {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Journals")
                                .font(.headline)

                            ForEach(recentReflections) { reflection in
                                RecentReflectionCard(reflection: reflection)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Reflect")
            .task { hydrateFromModel() }
            .onChange(of: todayArray.count) { hydrateFromModel() }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    Text("Saved")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.default, value: showSavedToast)
        }
    }

    private var recentReflections: [Reflection] {
        reflections.filter { $0.id != today.id }.prefix(5).map { $0 }
    }

    // MARK: - Model Sync
    private func hydrateFromModel() {
        // Load today's values into local state
        didWin = today.didWin
        mood = today.mood
        dayResult = today.dayResult
        selectedPrompt = today.prompt
        selectedTags = today.tags
        win = today.win
        obstacle = today.obstacle
        tomorrowFocus = today.tomorrowFocus
        note = today.note
        isDirty = false
    }

    private func updateToday(_ mutate: (Reflection) -> Void) {
        mutate(today)
        isDirty = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            save()
        }
    }

    private func toggleTag(_ tag: String) {
        if let index = selectedTags.firstIndex(of: tag) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }

        let updatedTags = selectedTags
        updateToday { $0.tags = updatedTags }
        Haptics.light()
    }

    private func resetToday() {
        today.didWin = false
        today.mood = 3
        today.dayResult = "Mixed"
        today.prompt = prompts[0]
        today.tags = []
        today.win = ""
        today.obstacle = ""
        today.tomorrowFocus = ""
        today.note = ""
        save(force: true, showFeedback: true)
        hydrateFromModel()
    }

    // Save with feedback and haptics
    private func save(force: Bool = false, showFeedback: Bool = false) {
        guard force || isDirty else { return }
        try? context.save()
        isDirty = false

        if showFeedback {
            Haptics.success()
            showSavedToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showSavedToast = false
            }
        }
    }
}

#Preview {
    ReflectionScreen()
}

struct JournalSummaryCard: View {
    var mood: Int
    var result: String
    var tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(summaryTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Mood \(mood)/5")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(result)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(resultTint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(resultTint.opacity(0.14), in: Capsule())
            }

            if tags.isEmpty == false {
                HStack(spacing: 6) {
                    ForEach(tags.prefix(3), id: \.self) { tag in
                        JournalTagLabel(title: tag)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var summaryTitle: String {
        switch mood {
        case 1...2: return "Write it out"
        case 4...5: return "Capture the win"
        default: return "Log the day"
        }
    }

    private var resultTint: Color {
        switch result {
        case "Won": return .green
        case "Missed": return .orange
        default: return .yellow
        }
    }
}

struct MoodPicker: View {
    @Binding var selectedMood: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    selectedMood = value
                    Haptics.light()
                } label: {
                    VStack(spacing: 5) {
                        Text("\(value)")
                            .font(.headline)
                        Text(label(for: value))
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedMood == value ? .black : .primary)
                    .background(selectedMood == value ? Color.green : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func label(for value: Int) -> String {
        switch value {
        case 1: return "Low"
        case 2: return "Heavy"
        case 3: return "Okay"
        case 4: return "Good"
        default: return "Great"
        }
    }
}

struct JournalChoiceButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(isSelected ? .black : .primary)
                .background(isSelected ? Color.green : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct JournalChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .black : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(isSelected ? Color.green : Color.white.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct JournalTextBlock: View {
    var title: String
    var prompt: String
    @Binding var text: String
    var limit: Int
    var lineRange: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(prompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(text.count)/\(limit)")
                    .font(.caption2)
                    .foregroundStyle(text.count >= limit ? .orange : .secondary)
            }

            TextField(prompt, text: $text, axis: .vertical)
                .lineLimit(lineRange)
                .submitLabel(.done)
                .onSubmit { Keyboard.dismiss() }
                .textFieldStyle(.plain)
                .padding()
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct JournalTagLabel: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.green)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.13), in: Capsule())
    }
}

struct RecentReflectionCard: View {
    var reflection: Reflection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(reflection.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 6) {
                    Label("\(reflection.mood)", systemImage: "face.smiling")
                        .labelStyle(.titleAndIcon)
                    Text(reflection.dayResult)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if reflection.win.isEmpty == false {
                Text(reflection.win)
                    .font(.headline)
                    .lineLimit(2)
            } else if reflection.note.isEmpty == false {
                Text(reflection.note)
                    .font(.headline)
                    .lineLimit(2)
            }

            if reflection.tags.isEmpty == false {
                HStack(spacing: 6) {
                    ForEach(reflection.tags.prefix(3), id: \.self) { tag in
                        JournalTagLabel(title: tag)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Coach
