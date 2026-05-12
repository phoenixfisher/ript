import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Day.date, order: .reverse) private var days: [Day]
    @StateObject private var appVM = AppViewModel()
    @StateObject private var homeVM = HomeViewModel()

    var body: some View {
        TabView {
            HomeScreen(appVM: appVM, homeVM: homeVM)
                .tabItem { Label("Home", systemImage: "house.fill") }
            WorkoutsScreen()
                .tabItem { Label("Workouts", systemImage: "dumbbell.fill") }
            MealsScreen()
                .tabItem { Label("Meals", systemImage: "fork.knife") }
            ReflectionScreen()
                .tabItem { Label("Reflect", systemImage: "moon.stars.fill") }
            StatsScreen()
                .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }
        }
        .task {
            SampleDataSeeder.seed(context: context)
            await NotificationScheduler.requestAuthorization()
            NotificationScheduler.scheduleDailyReminders()
        }
    }
}

// MARK: - Home
struct HomeScreen: View {
    @Environment(\.modelContext) private var context
    @Query(filter: { () -> Predicate<Day> in
        let todayStart = Calendar.current.startOfDay(for: Date())
        return #Predicate { $0.date == todayStart }
    }())
    private var todayArray: [Day]

    var appVM: AppViewModel
    @ObservedObject var homeVM: HomeViewModel

    init(appVM: AppViewModel, homeVM: HomeViewModel) {
        self.appVM = appVM
        self.homeVM = homeVM
    }

    private var today: Day {
        if let d = todayArray.first { return d }
        let new = Day()
        context.insert(new)
        return new
    }

    private var progress: Double { Double(today.completedHabits.count) / Double(HabitType.allCases.count) }

    private var totalXP: Int {
        (try? context.fetch(FetchDescriptor<Day>()))?.reduce(0) { $0 + $1.xpEarned } ?? 0
    }

    private var streak: Int {
        var count = 0
        var date = Calendar.current.startOfDay(for: Date())
        while true {
            if let d = try? context.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.date == date })).first, d.completedHabits.isEmpty == false {
                count += 1
                date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
            } else { break }
        }
        return count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        StreakBadge(count: streak)
                        Spacer()
                        LevelTag(title: appVM.level(for: totalXP).title)
                    }

                    VStack(spacing: 16) {
                        ProgressRing(progress: progress)
                        Text(homeVM.dailyQuote)
                            .font(.title2).bold()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .scale))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Wins").font(.title2).bold()
                        ForEach(HabitType.allCases) { habit in
                            ChecklistRow(title: habit.rawValue, isChecked: today.completedHabits.contains(habit)) {
                                toggle(habit)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    if today.perfectDay {
                        Text("Perfect Day! +50 XP")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .symbolEffect(.bounce)
                    }
                }
                .padding()
            }
            .navigationTitle("Ript")
            .toolbar { Button("Refresh Quote") { withAnimation { homeVM.resetQuote() } } }
        }
    }

    private func toggle(_ habit: HabitType) {
        var list = today.completedHabits
        if let idx = list.firstIndex(of: habit) {
            list.remove(at: idx)
            today.xpEarned -= habit.xpReward
        } else {
            list.append(habit)
            today.xpEarned += habit.xpReward
            Haptics.success()
        }
        today.completedHabits = list
        let allDone = HabitType.allCases.allSatisfy { list.contains($0) }
        today.perfectDay = allDone
        if allDone { today.xpEarned += 50 }
        try? context.save()
    }
}

// MARK: - Workouts
struct WorkoutsScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.name) private var workouts: [Workout]
    @StateObject private var timerVM = WorkoutTimerViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(workouts) { w in
                    NavigationLink(value: w.id) {
                        VStack(alignment: .leading) {
                            Text(w.name).font(.headline)
                            if let last = w.lastCompleted {
                                Text("Last: \(last.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationDestination(for: UUID.self) { id in
                if let w = workouts.first(where: { $0.id == id }) {
                    WorkoutDetail(workout: w, timerVM: timerVM)
                }
            }
        }
    }
}

struct WorkoutDetail: View {
    @Environment(\.modelContext) private var context
    var workout: Workout
    @ObservedObject var timerVM: WorkoutTimerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(workout.exercises) { ex in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(ex.name).bold()
                            Text("\(ex.sets) sets • \(ex.repsDescription)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(spacing: 8) {
                    Text("Simple Timer").font(.headline)
                    Text("\(timerVM.remaining)s").font(.largeTitle).monospacedDigit()
                    HStack {
                        Button {
                            timerVM.isRunning ? timerVM.stop() : timerVM.start(seconds: 60)
                        } label: {
                            Text(timerVM.isRunning ? "Stop" : "Start").foregroundStyle(.black)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                Button {
                    workout.lastCompleted = Date()
                    try? context.save()
                    Haptics.success()
                } label: {
                    Label("Mark Workout Complete", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity).foregroundStyle(.black)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle(workout.name)
    }
}

// MARK: - Meals
struct MealsScreen: View {
    @Query(sort: \MealIdea.title) private var meals: [MealIdea]
    var body: some View {
        NavigationStack {
            List {
                Section("Breakfast") { ForEach(meals.filter { $0.category == "Breakfast" }) { Text($0.title) } }
                Section("Lunch") { ForEach(meals.filter { $0.category == "Lunch" }) { Text($0.title) } }
                Section("Dinner") { ForEach(meals.filter { $0.category == "Dinner" }) { Text($0.title) } }
                Section("Snacks") { ForEach(meals.filter { $0.category == "Snacks" }) { Text($0.title) } }
            }
            .navigationTitle("Meal Ideas")
        }
    }
}

// MARK: - Reflection
struct ReflectionScreen: View {
    @Environment(\.modelContext) private var context
    @Query(filter: { () -> Predicate<Reflection> in
        let todayStart = Calendar.current.startOfDay(for: Date())
        return #Predicate { $0.date == todayStart }
    }())
    private var todayArray: [Reflection]
    @State private var didWin: Bool = false
    @State private var mood: Int = 3
    @State private var note: String = ""

    init() {}

    private var today: Reflection {
        if let r = todayArray.first { return r }
        let r = Reflection(didWin: false, mood: 3, note: "")
        context.insert(r)
        return r
    }

    var body: some View {
        Form {
            Toggle("Did I win today?", isOn: Binding(get: { today.didWin }, set: { today.didWin = $0; save() }))
            Picker("Mood", selection: Binding(get: { today.mood }, set: { today.mood = $0; save() })) {
                ForEach(1...5, id: \.self) { i in Text("\(i)") }
            }
            TextField("Short journal", text: Binding(get: { today.note }, set: { today.note = $0; save() }), axis: .vertical)
        }
        .navigationTitle("Daily Reflection")
    }

    private func save() { try? context.save() }
}

// MARK: - Stats
struct StatsScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMetric.date, order: .reverse) private var metrics: [BodyMetric]
    @Query(sort: \Day.date, order: .reverse) private var days: [Day]
    @State private var weight: String = ""
    @State private var waist: String = ""
    @State private var bodyFat: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Streak History").font(.headline)
                    Heatmap(values: Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0.completedHabits.count) }))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Track Body Metrics").font(.headline)
                        HStack {
                            TextField("Weight", text: $weight).keyboardType(.decimalPad)
                            TextField("Waist", text: $waist).keyboardType(.decimalPad)
                            TextField("Est. BF%", text: $bodyFat).keyboardType(.decimalPad)
                            Button("Add") { addMetric() }
                        }
                    }

                    Text("Completion %").font(.headline)
                    let completion = completionRate()
                    ProgressView(value: completion)
                        .tint(.green)
                    Text("\(Int(completion * 100))% of habits completed")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Stats")
        }
    }

    private func addMetric() {
        let m = BodyMetric(weight: Double(weight), waist: Double(waist), estBodyFat: Double(bodyFat))
        context.insert(m)
        try? context.save()
        weight = ""; waist = ""; bodyFat = ""
    }

    private func completionRate() -> Double {
        let total = days.count * HabitType.allCases.count
        guard total > 0 else { return 0 }
        let done = days.reduce(0) { $0 + $1.completedHabits.count }
        return Double(done) / Double(total)
    }
}

