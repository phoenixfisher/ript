import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case home
    case workouts
    case meals
    case reflect
    case coach
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Day.date, order: .reverse) private var days: [Day]
    @StateObject private var appVM = AppViewModel()
    @StateObject private var homeVM = HomeViewModel()
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeScreen(appVM: appVM, homeVM: homeVM, selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)
            WorkoutsScreen()
                .tabItem { Label("Workouts", systemImage: "dumbbell.fill") }
                .tag(AppTab.workouts)
            MealsScreen()
                .tabItem { Label("Meals", systemImage: "fork.knife") }
                .tag(AppTab.meals)
            ReflectionScreen()
                .tabItem { Label("Reflect", systemImage: "moon.stars.fill") }
                .tag(AppTab.reflect)
            CoachScreen()
                .tabItem { Label("Coach", systemImage: "sparkles") }
                .tag(AppTab.coach)
        }
        .scrollDismissesKeyboard(.interactively)
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
    @Query(sort: \Day.date, order: .reverse) private var allDays: [Day]
    @Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]
    @Query(sort: \MealIdea.title) private var meals: [MealIdea]

    var appVM: AppViewModel
    @ObservedObject var homeVM: HomeViewModel
    @Binding var selectedTab: AppTab

    init(appVM: AppViewModel, homeVM: HomeViewModel, selectedTab: Binding<AppTab>) {
        self.appVM = appVM
        self.homeVM = homeVM
        self._selectedTab = selectedTab
    }

    private var today: Day {
        if let d = todayArray.first { return d }
        let new = Day()
        context.insert(new)
        return new
    }

    private var progress: Double { Double(today.completedHabits.count) / Double(HabitType.allCases.count) }

    private var totalXP: Int {
        allDays.reduce(0) { $0 + $1.xpEarned }
    }

    private var streak: Int {
        var count = 0
        var date = Calendar.current.startOfDay(for: Date())
        while true {
            if let d = allDays.first(where: { $0.date == date }), d.completedHabits.isEmpty == false {
                count += 1
                date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
            } else { break }
        }
        return count
    }

    private var todaysSession: TrainingSession? {
        trainingSessions.first { Calendar.current.isDateInToday($0.date) }
    }

    private var nextSession: TrainingSession? {
        let today = Calendar.current.startOfDay(for: Date())
        return trainingSessions.first { $0.date >= today }
    }

    private var activeSession: TrainingSession? {
        todaysSession ?? nextSession
    }

    private var todaysReflection: Reflection? {
        reflections.first { Calendar.current.isDateInToday($0.date) }
    }

    private var coachContext: CoachContext {
        let anchor = activeSession
        let weekSessions = anchor.map { session in
            trainingSessions.filter { $0.weekLabel == session.weekLabel }
        } ?? []
        let fuelProfile = FuelProfile.profile(for: anchor)
        let mealPlan = SuggestedMealPlan.build(meals: meals, profile: fuelProfile, session: anchor)

        return CoachContext(
            todaysSession: todaysSession,
            nextSession: nextSession,
            todaysReflection: todaysReflection,
            todaysDay: today,
            weekSessions: weekSessions,
            fuelProfile: fuelProfile,
            mealPlan: mealPlan
        )
    }

    private var fuelProfile: FuelProfile {
        coachContext.fuelProfile
    }

    private var nextAction: HomeNextAction {
        if let session = activeSession, session.isCompleted == false {
            return HomeNextAction(
                title: "Start Workout",
                subtitle: session.requiredSummary,
                systemImage: "figure.run",
                tab: .workouts,
                tint: .green
            )
        }

        if today.completedHabits.contains(.proteinEveryMeal) == false {
            return HomeNextAction(
                title: "Review Meals",
                subtitle: fuelProfile.title,
                systemImage: "fork.knife",
                tab: .meals,
                tint: .orange
            )
        }

        if todaysReflection == nil || (todaysReflection?.note.isEmpty == true && todaysReflection?.win.isEmpty == true) {
            return HomeNextAction(
                title: "Reflect Tonight",
                subtitle: "Log the win, hard moment, and tomorrow focus.",
                systemImage: "moon.stars.fill",
                tab: .reflect,
                tint: .purple
            )
        }

        return HomeNextAction(
            title: "Ask Coach",
            subtitle: "Get a quick adjustment for the rest of the day.",
            systemImage: "sparkles",
            tab: .coach,
            tint: .cyan
        )
    }

    private var workoutsCompletedThisWeek: Int {
        coachContext.weekSessions.filter(\.isCompleted).count
    }

    private var journalEntriesThisWeek: Int {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return reflections.filter { week.contains($0.date) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HomeHeader(
                        date: Date(),
                        streak: streak,
                        levelTitle: appVM.level(for: totalXP).title
                    )

                    HomeScoreCard(
                        progress: progress,
                        completedWins: today.completedHabits.count,
                        totalWins: HabitType.allCases.count,
                        xp: today.xpEarned,
                        quote: homeVM.dailyQuote
                    )
                    
                    DailyWinsCard(today: today, onToggle: toggle)

                    HomeTodayPlanCard(
                        session: activeSession,
                        fuelProfile: fuelProfile,
                        readiness: coachContext.readiness
                    )
                    
                    HomeNextActionCard(action: nextAction) {
                        selectedTab = nextAction.tab
                    }

                    HomeMomentumCard(
                        streak: streak,
                        workoutsCompleted: workoutsCompletedThisWeek,
                        journalEntries: journalEntriesThisWeek
                    )

                    if today.perfectDay {
                        Text("Perfect Day! +50 XP")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .symbolEffect(.bounce)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle("Ript")
            .toolbar { Button("Refresh Quote") { withAnimation { homeVM.resetQuote() } } }
        }
    }

    private func toggle(_ habit: HabitType) {
        let wasPerfect = today.perfectDay
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
        if allDone && wasPerfect == false {
            today.xpEarned += 50
        } else if allDone == false && wasPerfect {
            today.xpEarned -= 50
        }
        today.xpEarned = max(0, today.xpEarned)
        try? context.save()
    }
}

struct HomeHeader: View {
    var date: Date
    var streak: Int
    var levelTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Today")
                        .font(.largeTitle)
                        .bold()
                }

                Spacer()

                StreakBadge(count: streak)
            }

            LevelTag(title: levelTitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HomeScoreCard: View {
    var progress: Double
    var completedWins: Int
    var totalWins: Int
    var xp: Int
    var quote: String

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                ProgressRing(progress: progress)
                    .frame(width: 104, height: 104)
                VStack(spacing: 2) {
                    Text("\(completedWins)/\(totalWins)")
                        .font(.title3)
                        .bold()
                    Text("wins")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("\(Int(progress * 100))% today")
                    .font(.title2)
                    .bold()
                Text("\(xp) XP earned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(quote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct HomeTodayPlanCard: View {
    var session: TrainingSession?
    var fuelProfile: FuelProfile
    var readiness: CoachReadiness

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today's Plan")
                    .font(.headline)
                Spacer()
                Label(readiness.title, systemImage: readiness.systemImage)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(readiness.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(readiness.tint.opacity(0.14), in: Capsule())
            }

            HomePlanRow(
                title: "Workout",
                value: session?.requiredSummary ?? "No scheduled workout",
                systemImage: "dumbbell.fill",
                tint: .green
            )

            HomePlanRow(
                title: "Fuel",
                value: fuelProfile.title,
                systemImage: fuelProfile.systemImage,
                tint: fuelProfile.tint
            )

            HomePlanRow(
                title: "Coach",
                value: coachLine,
                systemImage: "sparkles",
                tint: readiness.tint
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private var coachLine: String {
        switch readiness {
        case .push: return "Add extras only after required work."
        case .hold: return "Execute the plan and protect recovery."
        case .recover: return "Scale optional work and prioritize sleep."
        }
    }
}

struct HomePlanRow: View {
    var title: String
    var value: String
    var systemImage: String
    var tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

struct DailyWinsCard: View {
    var today: Day
    var onToggle: (HabitType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Wins")
                    .font(.headline)
                Spacer()
                Text("\(today.completedHabits.count)/\(HabitType.allCases.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(HabitType.allCases) { habit in
                    HomeHabitRow(
                        habit: habit,
                        isChecked: today.completedHabits.contains(habit)
                    ) {
                        onToggle(habit)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct HomeHabitRow: View {
    var habit: HabitType
    var isChecked: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChecked ? .green : .secondary)
                    .symbolEffect(.bounce, value: isChecked)

                Text(habit.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                Text("+\(habit.xpReward)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct HomeNextAction {
    var title: String
    var subtitle: String
    var systemImage: String
    var tab: AppTab
    var tint: Color
}

struct HomeNextActionCard: View {
    var action: HomeNextAction
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: action.systemImage)
                    .font(.title3)
                    .foregroundStyle(action.tint)
                    .frame(width: 40, height: 40)
                    .background(action.tint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Action")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(action.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(action.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(action.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct HomeMomentumCard: View {
    var streak: Int
    var workoutsCompleted: Int
    var journalEntries: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Momentum")
                .font(.headline)

            HStack(spacing: 10) {
                HomeMetricTile(value: "\(streak)", label: "streak", systemImage: "flame.fill", tint: .orange)
                HomeMetricTile(value: "\(workoutsCompleted)", label: "workouts", systemImage: "checkmark.seal.fill", tint: .green)
                HomeMetricTile(value: "\(journalEntries)", label: "journals", systemImage: "book.closed.fill", tint: .purple)
            }
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct HomeMetricTile: View {
    var value: String
    var label: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(tint)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
