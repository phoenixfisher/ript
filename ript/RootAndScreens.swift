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
    @Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]
    @Query(sort: \Workout.name) private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let session = todaysSession {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Today")
                                .font(.title2)
                                .bold()

                            NavigationLink {
                                TrainingSessionDetail(session: session)
                            } label: {
                                TodayTrainingCard(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    } else if let next = nextSession {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Next Workout")
                                .font(.title2)
                                .bold()

                            NavigationLink {
                                TrainingSessionDetail(session: next)
                            } label: {
                                TodayTrainingCard(session: next)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if weekSessions.isEmpty == false {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("This Week")
                                .font(.headline)

                            VStack(spacing: 10) {
                                ForEach(weekSessions) { session in
                                    NavigationLink {
                                        TrainingSessionDetail(session: session)
                                    } label: {
                                        TrainingWeekRow(session: session, isToday: Calendar.current.isDateInToday(session.date))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if workouts.isEmpty == false {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Strength & Core Library")
                                    .font(.headline)
                                Spacer()
                                Text("Optional")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(spacing: 10) {
                                ForEach(workouts) { workout in
                                    NavigationLink {
                                        WorkoutDetail(workout: workout)
                                    } label: {
                                        WorkoutLibraryRow(workout: workout)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Workouts")
        }
    }

    private var todaysSession: TrainingSession? {
        trainingSessions.first { Calendar.current.isDateInToday($0.date) }
    }

    private var nextSession: TrainingSession? {
        let today = Calendar.current.startOfDay(for: Date())
        return trainingSessions.first { $0.date >= today }
    }

    private var weekSessions: [TrainingSession] {
        guard let anchor = todaysSession ?? nextSession else { return [] }
        return trainingSessions.filter { $0.weekLabel == anchor.weekLabel }
    }
}

struct TodayTrainingCard: View {
    var session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.weekLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(session.title)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(session.focus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: session.isCompleted ? "checkmark.seal.fill" : "chevron.right")
                    .foregroundStyle(session.isCompleted ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: session.progress)
                    .tint(.green)
                Text("\(session.completedSegmentCount)/\(session.segments.count) items done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(session.segments.prefix(3)) { segment in
                    HStack(spacing: 8) {
                        Image(systemName: segment.isCompleted ? "checkmark.circle.fill" : segment.kind.systemImage)
                            .foregroundStyle(segment.isCompleted ? .green : segment.kind.tint)
                        Text(segment.title)
                            .font(.subheadline)
                        Spacer()
                        Text(segment.priority.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct TrainingWeekRow: View {
    var session: TrainingSession
    var isToday: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(session.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isToday ? .green : .secondary)
                Text(session.date.formatted(.dateTime.day()))
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .frame(width: 46)

            VStack(alignment: .leading, spacing: 5) {
                Text(session.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(session.requiredSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "chevron.right")
                .foregroundStyle(session.isCompleted ? .green : .secondary)
        }
        .padding()
        .background(isToday ? Color.green.opacity(0.12) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct TrainingSessionDetail: View {
    @Environment(\.modelContext) private var context
    var session: TrainingSession

    private let effortOptions = ["Easy", "Good", "Hard"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.date.formatted(date: .complete, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(session.title)
                        .font(.largeTitle)
                        .bold()
                    Text(session.focus)
                        .foregroundStyle(.secondary)

                    ProgressView(value: session.progress)
                        .tint(.green)
                        .padding(.top, 6)
                    Text("\(session.completedSegmentCount) of \(session.segments.count) items checked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(TrainingSegmentPriority.allCases) { priority in
                    let segments = session.segments.filter { $0.priority == priority }
                    if segments.isEmpty == false {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(priority.title)
                                .font(.headline)

                            ForEach(segments) { segment in
                                TrainingSegmentRow(segment: segment) {
                                    toggleSegment(segment.id)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Effort")
                        .font(.headline)
                    Picker("Effort", selection: effortBinding) {
                        ForEach(effortOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Button {
                    toggleSessionCompletion()
                } label: {
                    Label(session.isCompleted ? "Mark Incomplete" : "Mark Session Complete", systemImage: session.isCompleted ? "xmark.circle.fill" : "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.black)
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.canComplete == false && session.isCompleted == false)
            }
            .padding()
        }
        .navigationTitle(session.weekLabel)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var effortBinding: Binding<String> {
        Binding {
            session.effortRating ?? "Good"
        } set: { newValue in
            session.effortRating = newValue
            try? context.save()
        }
    }

    private func toggleSegment(_ id: UUID) {
        var updated = session.segments
        guard let index = updated.firstIndex(where: { $0.id == id }) else { return }

        updated[index].isCompleted.toggle()
        session.segments = updated

        if session.isCompleted && session.canComplete == false {
            session.isCompleted = false
            session.completedAt = nil
        }

        try? context.save()
        Haptics.light()
    }

    private func toggleSessionCompletion() {
        if session.isCompleted {
            session.isCompleted = false
            session.completedAt = nil
        } else {
            session.isCompleted = true
            session.completedAt = Date()
            creditWorkoutHabitIfNeeded()
            Haptics.success()
        }

        try? context.save()
    }

    private func creditWorkoutHabitIfNeeded() {
        guard Calendar.current.isDateInToday(session.date) else { return }

        let todayStart = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<Day>(predicate: #Predicate { $0.date == todayStart })
        let day: Day

        if let existing = try? context.fetch(descriptor).first {
            day = existing
        } else {
            let newDay = Day(date: todayStart)
            context.insert(newDay)
            day = newDay
        }

        var habits = day.completedHabits
        guard habits.contains(.coreOrWorkout) == false else { return }

        habits.append(.coreOrWorkout)
        day.completedHabits = habits
        day.xpEarned += HabitType.coreOrWorkout.xpReward

        if HabitType.allCases.allSatisfy({ habits.contains($0) }) && day.perfectDay == false {
            day.perfectDay = true
            day.xpEarned += 50
        }
    }
}

struct TrainingSegmentRow: View {
    var segment: TrainingSegment
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: segment.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(segment.isCompleted ? .green : .secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        SegmentKindBadge(kind: segment.kind, priority: nil)
                        SegmentKindBadge(kind: segment.kind, priority: segment.priority)
                    }

                    Text(segment.title)
                        .font(.headline)
                    Text(segment.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct WorkoutLibraryRow: View {
    var workout: Workout

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(workout.exercises.count) exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let last = workout.lastCompleted {
                    Text("Last: \(last.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct WorkoutDetail: View {
    @Environment(\.modelContext) private var context
    var workout: Workout
    @State private var completedSets: [UUID: Int] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Optional add-on")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(workout.name)
                        .font(.largeTitle)
                        .bold()

                    ProgressView(value: setProgress)
                        .tint(.green)
                    Text("\(completedSetCount)/\(totalSetCount) sets done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(workout.exercises) { ex in
                    Button {
                        advanceSet(for: ex)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(ex.name)
                                    .font(.headline)
                                Text("\(ex.sets) sets - \(ex.repsDescription)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            SetDots(count: ex.sets, completed: completedSets[ex.id, default: 0])
                        }
                        .padding()
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    workout.lastCompleted = Date()
                    try? context.save()
                    Haptics.success()
                } label: {
                    Label("Mark Add-On Complete", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity).foregroundStyle(.black)
                }
                .buttonStyle(.borderedProminent)
                .disabled(totalSetCount > 0 && completedSetCount < totalSetCount)
            }
            .padding()
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var totalSetCount: Int {
        workout.exercises.reduce(0) { $0 + $1.sets }
    }

    private var completedSetCount: Int {
        workout.exercises.reduce(0) { total, exercise in
            total + completedSets[exercise.id, default: 0]
        }
    }

    private var setProgress: Double {
        guard totalSetCount > 0 else { return 0 }
        return Double(completedSetCount) / Double(totalSetCount)
    }

    private func advanceSet(for exercise: Exercise) {
        let current = completedSets[exercise.id, default: 0]
        completedSets[exercise.id] = current >= exercise.sets ? 0 : current + 1
        Haptics.light()
    }
}

private extension TrainingSession {
    var completedSegmentCount: Int {
        segments.filter(\.isCompleted).count
    }

    var progress: Double {
        guard segments.isEmpty == false else { return 0 }
        return Double(completedSegmentCount) / Double(segments.count)
    }

    var requiredSummary: String {
        let required = segments
            .filter { $0.priority == .required }
            .map(\.title)

        return required.isEmpty ? "No required work" : required.joined(separator: " + ")
    }

    var canComplete: Bool {
        let required = segments.filter { $0.priority == .required }
        guard required.isEmpty == false else { return true }
        return required.allSatisfy(\.isCompleted)
    }
}

// MARK: - Meals
struct MealsScreen: View {
    @Query(sort: \MealIdea.title) private var meals: [MealIdea]
    @Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SuggestedMealPlanSection(plan: suggestedPlan)
                    
                    FuelTodayCard(session: todaysSession, profile: fuelProfile)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Browse Options")
                            .font(.headline)

                        if favoriteMeals.isEmpty == false {
                            MealLibrarySection(title: "Favorites", meals: favoriteMeals)
                        }

                        ForEach(categoryOrder, id: \.self) { category in
                            let categoryMeals = meals.filter { $0.category == category }
                            if categoryMeals.isEmpty == false {
                                MealLibrarySection(title: category, meals: categoryMeals)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Meals")
        }
    }

    private var todaysSession: TrainingSession? {
        trainingSessions.first { Calendar.current.isDateInToday($0.date) }
    }

    private var fuelProfile: FuelProfile {
        FuelProfile.profile(for: todaysSession)
    }

    private var suggestedPlan: SuggestedMealPlan {
        SuggestedMealPlan.build(meals: meals, profile: fuelProfile, session: todaysSession)
    }

    private var favoriteMeals: [MealIdea] {
        meals.filter(\.isFavorite)
    }

    private var categoryOrder: [String] {
        ["Breakfast", "Lunch", "Dinner", "Snacks"]
    }
}

struct FuelTodayCard: View {
    var session: TrainingSession?
    var profile: FuelProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Fuel")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 14) {
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: profile.systemImage)
                        .font(.title2)
                        .foregroundStyle(profile.tint)
                        .frame(width: 34, height: 34)
                        .background(profile.tint.opacity(0.15), in: Circle())
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(profile.title)
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(session?.requiredSummary ?? "No scheduled workout found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(profile.guidance, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct SuggestedMealPlanSection: View {
    var plan: SuggestedMealPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Today's Plan")
                    .font(.headline)
            }

            VStack(spacing: 10) {
                ForEach(plan.items) { item in
                    if let meal = item.meal {
                        NavigationLink {
                            MealDetailScreen(meal: meal)
                        } label: {
                            SuggestedMealPlanRow(item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        SuggestedMealPlanRow(item: item)
                    }
                }
            }
        }
    }
}

struct SuggestedMealPlanRow: View {
    var item: SuggestedMealPlanItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.subheadline)
                .foregroundStyle(item.tint)
                .frame(width: 30, height: 30)
                .background(item.tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    if item.meal?.isFavorite == true {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(item.meal?.title ?? item.fallbackTitle)
                    .font(.headline)

                Text(item.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let meal = item.meal {
                    HStack(spacing: 10) {
                        Label("\(meal.proteinGrams)g", systemImage: "bolt.fill")
                        Label("\(meal.prepMinutes)m", systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.meal != nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MealSuggestionSection: View {
    var title: String
    var subtitle: String
    var meals: [MealIdea]

    var body: some View {
        if meals.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach(meals) { meal in
                        NavigationLink {
                            MealDetailScreen(meal: meal)
                        } label: {
                            MealIdeaRow(meal: meal)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct MealLibrarySection: View {
    var title: String
    var meals: [MealIdea]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(meals) { meal in
                    NavigationLink {
                        MealDetailScreen(meal: meal)
                    } label: {
                        MealIdeaRow(meal: meal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct MealIdeaRow: View {
    var meal: MealIdea

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(meal.title)
                        .font(.headline)
                        .lineLimit(2)
                    if meal.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 10) {
                    Label("\(meal.proteinGrams)g", systemImage: "bolt.fill")
                    Label("\(meal.prepMinutes)m", systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    ForEach(meal.goalTags.prefix(3), id: \.self) { tag in
                        MealTagChip(title: tag)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MealDetailScreen: View {
    @Environment(\.modelContext) private var context
    var meal: MealIdea

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(meal.category)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(meal.title)
                        .font(.largeTitle)
                        .bold()

                    HStack(spacing: 10) {
                        MealMetricCard(value: "\(meal.proteinGrams)g", label: "Protein")
                        MealMetricCard(value: "\(meal.prepMinutes)m", label: "Prep")
                    }

                    Text(meal.bestTiming)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(meal.goalTags, id: \.self) { tag in
                            MealTagChip(title: tag)
                        }
                    }
                }

                if meal.ingredients.isEmpty == false {
                    MealDetailBlock(title: "Ingredients", items: meal.ingredients)
                }

                if meal.steps.isEmpty == false {
                    MealDetailBlock(title: "Quick Prep", items: meal.steps)
                }

                if meal.notes.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why It Fits")
                            .font(.headline)
                        Text(meal.notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                meal.isFavorite.toggle()
                try? context.save()
                Haptics.light()
            } label: {
                Image(systemName: meal.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(meal.isFavorite ? .yellow : .primary)
            }
            .accessibilityLabel(meal.isFavorite ? "Remove Favorite" : "Add Favorite")
        }
    }
}

struct MealMetricCard: View {
    var value: String
    var label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MealDetailBlock: View {
    var title: String
    var items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(0.08), in: Circle())
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct MealTagChip: View {
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

struct FuelProfile {
    var title: String
    var systemImage: String
    var tint: Color
    var guidance: [String]
    var preWorkoutTags: Set<String>
    var postWorkoutTags: Set<String>

    static func profile(for session: TrainingSession?) -> FuelProfile {
        guard let session else {
            return FuelProfile(
                title: "Balanced Fuel Day",
                systemImage: "fork.knife",
                tint: .green,
                guidance: ["Protein every meal", "Build meals around lean protein and produce", "Use carbs around training when needed"],
                preWorkoutTags: ["Pre-Workout", "Quick"],
                postWorkoutTags: ["Post-Workout", "High Protein"]
            )
        }

        let segments = session.segments
        let hasRest = segments.contains { $0.kind == .rest }
        let hasBrick = segments.contains { $0.kind == .brick }
        let hasLongSession = segments.contains { segment in
            segment.title.localizedCaseInsensitiveContains("2 hr") ||
            segment.title.localizedCaseInsensitiveContains("90 min") ||
            segment.detail.localizedCaseInsensitiveContains("long")
        }
        let hasIntensity = segments.contains { segment in
            segment.detail.localizedCaseInsensitiveContains("hard") ||
            segment.detail.localizedCaseInsensitiveContains("tempo") ||
            segment.detail.localizedCaseInsensitiveContains("race pace") ||
            segment.detail.localizedCaseInsensitiveContains("faster")
        }

        if hasRest {
            return FuelProfile(
                title: "Recovery Fuel Day",
                systemImage: "leaf.fill",
                tint: .blue,
                guidance: ["Protein every meal", "Keep carbs moderate unless hunger is high", "Hydrate and keep meals simple"],
                preWorkoutTags: ["Lean", "High Protein", "No-Cook"],
                postWorkoutTags: ["High Protein", "Lean"]
            )
        }

        if hasBrick || hasLongSession {
            return FuelProfile(
                title: "Higher Carb Training Day",
                systemImage: "flame.fill",
                tint: .orange,
                guidance: ["Carbs before training", "Protein plus carbs after", "Use electrolytes for long bike or brick work"],
                preWorkoutTags: ["Pre-Workout", "High Carb", "Long Ride"],
                postWorkoutTags: ["Post-Workout", "High Protein", "High Carb"]
            )
        }

        if hasIntensity {
            return FuelProfile(
                title: "Quality Session Fuel",
                systemImage: "bolt.fill",
                tint: .yellow,
                guidance: ["Do not start hard work under-fueled", "Use easy carbs before training", "Recover with protein plus carbs"],
                preWorkoutTags: ["Pre-Workout", "Quick", "High Carb"],
                postWorkoutTags: ["Post-Workout", "High Protein"]
            )
        }

        return FuelProfile(
            title: "Balanced Fuel Day",
            systemImage: "fork.knife",
            tint: .green,
            guidance: ["Protein every meal", "Add carbs near swim, bike, or run", "Keep dinner lean and filling"],
            preWorkoutTags: ["Pre-Workout", "Quick"],
            postWorkoutTags: ["Post-Workout", "High Protein", "Lean"]
        )
    }
}

struct SuggestedMealPlan {
    var items: [SuggestedMealPlanItem]

    static func build(meals: [MealIdea], profile: FuelProfile, session: TrainingSession?) -> SuggestedMealPlan {
        let isRestDay = session?.segments.contains { $0.kind == .rest } ?? false
        let isLongDay = profile.preWorkoutTags.contains("Long Ride")
        let isCarbDay = profile.preWorkoutTags.contains("High Carb")
        var usedIDs = Set<UUID>()

        func take(title: String? = nil, category: String? = nil, preferredTags: [String]) -> MealIdea? {
            let candidates = meals.filter { meal in
                let matchesCategory = category.map { meal.category == $0 } ?? true
                return matchesCategory && usedIDs.contains(meal.id) == false
            }

            if let title, let exact = candidates.first(where: { $0.title == title }) {
                usedIDs.insert(exact.id)
                return exact
            }

            let ranked = candidates.sorted { lhs, rhs in
                let lhsScore = lhs.score(for: preferredTags)
                let rhsScore = rhs.score(for: preferredTags)
                if lhsScore == rhsScore { return lhs.title < rhs.title }
                return lhsScore > rhsScore
            }

            guard let chosen = ranked.first else { return nil }
            usedIDs.insert(chosen.id)
            return chosen
        }

        let breakfast = take(
            title: isCarbDay ? "Protein oats" : nil,
            category: "Breakfast",
            preferredTags: isCarbDay ? ["High Carb", "Pre-Workout", "High Protein"] : ["High Protein", "Lean", "Quick"]
        )
        let lunch = take(
            title: isCarbDay ? "Chicken rice bowl" : "Turkey sandwich",
            category: "Lunch",
            preferredTags: isCarbDay ? ["Post-Workout", "High Carb", "High Protein"] : ["High Protein", "Quick", "Lean"]
        )
        let dinner = take(
            title: isLongDay || isCarbDay ? "Chicken + rice" : "Salmon + sweet potato",
            category: "Dinner",
            preferredTags: isCarbDay ? ["Post-Workout", "High Carb", "High Protein"] : ["Lean", "High Protein"]
        )
        let snack = take(
            title: isCarbDay ? "Banana + peanut butter toast" : "Cottage cheese bowl",
            category: "Snacks",
            preferredTags: isCarbDay ? ["Pre-Workout", "High Carb", "Quick"] : ["High Protein", "Lean", "No-Cook"]
        )
        let sessionFuel = isRestDay ? nil : take(
            title: isLongDay ? "Electrolyte carb bottle" : nil,
            category: "Snacks",
            preferredTags: isLongDay ? ["Long Ride", "High Carb"] : ["Pre-Workout", "Quick", "High Carb"]
        )

        let sessionFuelTitle = isRestDay ? "Hydration + normal meals" : "Pick quick training fuel"
        let sessionFuelNote = if isRestDay {
            "No extra workout fuel needed today."
        } else if isLongDay {
            "Use this around the long bike or brick."
        } else {
            "Use this before training if your last meal was light."
        }

        return SuggestedMealPlan(items: [
            SuggestedMealPlanItem(title: "Breakfast", fallbackTitle: "Pick a protein-forward breakfast", note: isCarbDay ? "Start with protein plus easy carbs." : "Keep it filling and protein-forward.", systemImage: "sun.max.fill", tint: .yellow, meal: breakfast),
            SuggestedMealPlanItem(title: "Lunch", fallbackTitle: "Pick a high-protein lunch", note: isCarbDay ? "Recover with carbs and lean protein." : "Stay steady without overcomplicating it.", systemImage: "fork.knife", tint: .green, meal: lunch),
            SuggestedMealPlanItem(title: "Dinner", fallbackTitle: "Pick a lean dinner", note: isCarbDay ? "Refill glycogen without making dinner chaotic." : "Lean protein, produce, and enough carbs for recovery.", systemImage: "moon.fill", tint: .indigo, meal: dinner),
            SuggestedMealPlanItem(title: "Snack", fallbackTitle: "Pick a simple snack", note: isCarbDay ? "Use this as a bridge into training." : "Easy protein without much prep.", systemImage: "takeoutbag.and.cup.and.straw.fill", tint: .mint, meal: snack),
            SuggestedMealPlanItem(title: "Session Fuel", fallbackTitle: sessionFuelTitle, note: sessionFuelNote, systemImage: isRestDay ? "drop.fill" : "bolt.fill", tint: profile.tint, meal: sessionFuel)
        ])
    }
}

struct SuggestedMealPlanItem: Identifiable {
    var id: String { title }
    var title: String
    var fallbackTitle: String
    var note: String
    var systemImage: String
    var tint: Color
    var meal: MealIdea?
}

private extension Array where Element == MealIdea {
    func matching(tags: Set<String>, limit: Int) -> [MealIdea] {
        filter { meal in
            tags.isDisjoint(with: Set(meal.goalTags)) == false
        }
        .prefix(limit)
        .map { $0 }
    }
}

private extension MealIdea {
    func score(for preferredTags: [String]) -> Int {
        preferredTags.reduce(isFavorite ? 1 : 0) { score, tag in
            goalTags.contains(tag) ? score + 1 : score
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

    // Local UI state
    @State private var didWin: Bool = false
    @State private var mood: Int = 3
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

    private let noteLimit = 280

    var body: some View {
        Form {
            Section("Today") {
                Toggle("Did I win today?", isOn: Binding(get: { didWin }, set: { new in
                    didWin = new
                    updateModel { $0.didWin = new }
                }))

                Picker("Mood", selection: Binding(get: { mood }, set: { new in
                    mood = new
                    updateModel { $0.mood = new }
                })) {
                    ForEach(1...5, id: \.self) { i in Text("\(i)") }
                }

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Short journal", text: Binding(get: { note }, set: { new in
                        let trimmed = String(new.prefix(noteLimit))
                        note = trimmed
                        updateModel { $0.note = trimmed }
                    }), axis: .vertical)
                    .lineLimit(3...8)

                    HStack {
                        Spacer()
                        Text("\(note.count)/\(noteLimit)")
                            .font(.caption)
                            .foregroundStyle(note.count >= noteLimit ? .orange : .secondary)
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
                        save(force: true)
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isDirty)
                }
            }

            if !recentReflections.isEmpty {
                Section("Recent Reflections") {
                    ForEach(recentReflections) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(r.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Label("\(r.mood)", systemImage: "face.smiling")
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(.yellow)
                            }
                            Text(r.note).font(.body)
                        }
                    }
                }
            }
        }
        .navigationTitle("Daily Reflection")
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

    private var recentReflections: [Reflection] {
        reflections.filter { $0.id != today.id }.prefix(5).map { $0 }
    }

    // MARK: - Model Sync
    private func hydrateFromModel() {
        // Load today's values into local state
        didWin = today.didWin
        mood = today.mood
        note = today.note
        isDirty = false
    }

    private func updateModel(_ mutate: (inout Reflection) -> Void) {
        var t = today
        mutate(&t)
        isDirty = true
        // Debounced autosave after small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            save()
        }
    }

    private func resetToday() {
        today.didWin = false
        today.mood = 3
        today.note = ""
        save(force: true)
        hydrateFromModel()
    }

    // Save with feedback and haptics
    private func save(force: Bool = false) {
        guard force || isDirty else { return }
        try? context.save()
        isDirty = false
        Haptics.success()
        showSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showSavedToast = false
        }
    }
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
