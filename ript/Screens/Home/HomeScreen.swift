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

    @ObservedObject var homeVM: HomeViewModel
    @Binding var selectedTab: AppTab
    @AppStorage("homeCardOrder") private var homeCardOrderStorage: String = ""
    @State private var showHomeCustomizer: Bool = false
    @State private var createdToday: Day?

    init(homeVM: HomeViewModel, selectedTab: Binding<AppTab>) {
        self.homeVM = homeVM
        self._selectedTab = selectedTab
    }

    private var today: Day? {
        todayArray.first ?? createdToday
    }

    private var completedHabitsToday: [HabitType] {
        today?.completedHabits ?? []
    }

    private var todayXP: Int {
        today?.xpEarned ?? 0
    }

    private var isPerfectDay: Bool {
        today?.perfectDay ?? false
    }

    private var progress: Double { Double(completedHabitsToday.count) / Double(HabitType.allCases.count) }

    private var totalXP: Int {
        allDays.reduce(0) { $0 + $1.xpEarned }
    }

    private var streak: Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let hasCompletedToday = allDays.first { calendar.isDate($0.date, inSameDayAs: todayStart) }?.completedHabits.isEmpty == false
        let startDate = hasCompletedToday ? todayStart : calendar.date(byAdding: .day, value: -1, to: todayStart)!

        return completedDayStreak(startingAt: startDate)
    }

    private func completedDayStreak(startingAt startDate: Date) -> Int {
        let calendar = Calendar.current
        var count = 0
        var date = calendar.startOfDay(for: startDate)

        while true {
            if let d = allDays.first(where: { calendar.isDate($0.date, inSameDayAs: date) }), d.completedHabits.isEmpty == false {
                count += 1
                date = calendar.date(byAdding: .day, value: -1, to: date)!
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

        if completedHabitsToday.contains(.proteinEveryMeal) == false {
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

    private var orderedHomeCards: [HomeCardKind] {
        HomeCardKind.cards(from: homeCardOrderStorage)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HomeHeader(
                        date: Date(),
                        streak: streak,
                        quote: homeVM.dailyQuote
                    ) {
                        withAnimation {
                            homeVM.resetQuote()
                        }
                    }

                    ForEach(orderedHomeCards) { card in
                        homeCard(card)
                    }

                    if isPerfectDay {
                        Text("Perfect Day! +50 XP")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .symbolEffect(.bounce)
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        showHomeCustomizer = true
                    } label: {
                        Text("Customize Home")
                            .tint(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .accessibilityLabel("Customize Home")
                }
                .padding()
            }
            .navigationTitle("Home")
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
            .sheet(isPresented: $showHomeCustomizer) {
                NavigationStack {
                    HomeCustomizeSheet(cards: orderedHomeCards) { cards in
                        homeCardOrderStorage = HomeCardKind.storageValue(for: cards)
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    @ViewBuilder
    private func homeCard(_ card: HomeCardKind) -> some View {
        switch card {
        case .score:
            HomeScoreCard(
                progress: progress,
                completedWins: completedHabitsToday.count,
                totalWins: HabitType.allCases.count,
                xp: todayXP,
                completedHabits: completedHabitsToday,
                onToggle: toggle
            )
        case .todaysPlan:
            HomeTodayPlanCard(
                session: activeSession,
                fuelProfile: fuelProfile,
                readiness: coachContext.readiness
            )
        case .nextAction:
            HomeNextActionCard(action: nextAction) {
                selectedTab = nextAction.tab
            }
        case .momentum:
            HomeMomentumCard(
                streak: streak,
                workoutsCompleted: workoutsCompletedThisWeek,
                journalEntries: journalEntriesThisWeek
            )
        }
    }

    private func toggle(_ habit: HabitType) {
        let day = todayForMutation()
        let wasPerfect = day.perfectDay
        var list = day.completedHabits
        if let idx = list.firstIndex(of: habit) {
            list.remove(at: idx)
            day.xpEarned -= habit.xpReward
        } else {
            list.append(habit)
            day.xpEarned += habit.xpReward
            Haptics.success()
        }
        day.completedHabits = list
        let allDone = HabitType.allCases.allSatisfy { list.contains($0) }
        day.perfectDay = allDone
        if allDone && wasPerfect == false {
            day.xpEarned += 50
        } else if allDone == false && wasPerfect {
            day.xpEarned -= 50
        }
        day.xpEarned = max(0, day.xpEarned)

        do {
            try context.save()
            createdToday = day
        } catch {
        }
    }

    private func todayForMutation() -> Day {
        if let today {
            return today
        }

        let todayStart = Calendar.current.startOfDay(for: Date())
        var descriptor = FetchDescriptor<Day>(predicate: #Predicate { $0.date == todayStart })
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            createdToday = existing
            return existing
        }

        let newDay = Day(date: todayStart)
        context.insert(newDay)
        return newDay
    }
}

enum HomeCardKind: String, CaseIterable, Identifiable {
    case score
    case todaysPlan
    case nextAction
    case momentum

    var id: String { rawValue }

    var title: String {
        switch self {
        case .score:
            return "Daily Progress"
        case .todaysPlan:
            return "Today's Plan"
        case .nextAction:
            return "Next Action"
        case .momentum:
            return "Momentum"
        }
    }

    var systemImage: String {
        switch self {
        case .score:
            return "chart.line.uptrend.xyaxis"
        case .todaysPlan:
            return "calendar"
        case .nextAction:
            return "arrow.right.circle.fill"
        case .momentum:
            return "flame.fill"
        }
    }

    static func cards(from storage: String) -> [HomeCardKind] {
        var cards: [HomeCardKind] = []

        for rawValue in storage.split(separator: ",").map(String.init) {
            guard let card = HomeCardKind(rawValue: rawValue), cards.contains(card) == false else { continue }
            cards.append(card)
        }

        for card in allCases where cards.contains(card) == false {
            cards.append(card)
        }

        return cards
    }

    static func storageValue(for cards: [HomeCardKind]) -> String {
        cards.map(\.rawValue).joined(separator: ",")
    }
}

struct HomeCustomizeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cards: [HomeCardKind]
    let onSave: ([HomeCardKind]) -> Void

    init(cards: [HomeCardKind], onSave: @escaping ([HomeCardKind]) -> Void) {
        _cards = State(initialValue: cards)
        self.onSave = onSave
    }

    var body: some View {
        List {
            Section {
                ForEach(cards) { card in
                    Label(card.title, systemImage: card.systemImage)
                }
                .onMove { source, destination in
                    cards.move(fromOffsets: source, toOffset: destination)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Customize Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Reset") {
                    cards = HomeCardKind.allCases
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    onSave(cards)
                    dismiss()
                }
            }
        }
    }
}
