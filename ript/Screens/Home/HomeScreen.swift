import SwiftUI
import SwiftData

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
                        levelTitle: appVM.level(for: totalXP).title,
                        quote: homeVM.dailyQuote
                    ) {
                        withAnimation {
                            homeVM.resetQuote()
                        }
                    }

                    HomeScoreCard(
                        progress: progress,
                        completedWins: today.completedHabits.count,
                        totalWins: HabitType.allCases.count,
                        xp: today.xpEarned
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsScreen()
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }
            }
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
