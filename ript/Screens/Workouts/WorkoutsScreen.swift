import SwiftUI
import SwiftData

struct WorkoutsScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingPlan.createdAt, order: .reverse) private var trainingPlans: [TrainingPlan]
    @Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]
    @Query(sort: \Workout.name) private var workouts: [Workout]
    @Query(sort: \HealthWorkout.startDate, order: .reverse) private var healthWorkouts: [HealthWorkout]
    @State private var selectedPlanID: UUID?
    @State private var selectedWeekLabel: String?
    @State private var selectedMonthStart: Date?
    @State private var scheduleViewMode: TrainingScheduleViewMode = .week
    @State private var showCreatePlanSheet = false
    @AppStorage("distanceUnit") private var distanceUnit: String = "Miles"
    @AppStorage("healthUseWorkouts") private var healthUseWorkouts: Bool = true

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

                            if todaysHealthWorkouts.isEmpty == false {
                                TodayHealthWorkoutsCard(
                                    session: session,
                                    workouts: todaysHealthWorkouts,
                                    distanceUnit: distanceUnit,
                                    canMatchToPlan: canMatchTodaysHealthWorkouts(to: session),
                                    onMatchToPlan: {
                                        matchTodaysHealthWorkouts(to: session)
                                    }
                                )
                            }
                        }
                    } else if todaysHealthWorkouts.isEmpty == false {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Today")
                                .font(.title2)
                                .bold()

                            TodayHealthWorkoutsCard(
                                session: nil,
                                workouts: todaysHealthWorkouts,
                                distanceUnit: distanceUnit,
                                canMatchToPlan: false,
                                onMatchToPlan: {}
                            )
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

                    if trainingPlans.isEmpty == false {
                        planHistorySection
                    }


                    if visibleSessions.isEmpty == false {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Button {
                                    jumpToTodaySchedule()
                                } label: {
                                    if canJumpToTodaySchedule {
                                        Text("Today \(Image(systemName: "arrow.right"))")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.primary)
                                            .padding(.horizontal, 9)
                                            .frame(height: 28)
                                            .background(Color.white.opacity(0.06), in: Capsule())
                                    }
                                }
                                .disabled(canJumpToTodaySchedule == false)
                                .buttonStyle(.plain)
                                .frame(width: 90, alignment: .leading)

                                HStack(spacing: 6) {
                                    Button {
                                        moveSchedule(by: -1)
                                    } label: {
                                        Image(systemName: "chevron.left")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(canMoveSchedule(by: -1) ? Color.primary : Color.secondary.opacity(0.35))
                                            .frame(width: 28, height: 28)
                                            .background(Color.white.opacity(0.06), in: Circle())
                                    }
                                    .disabled(canMoveSchedule(by: -1) == false)
                                    .accessibilityLabel(scheduleViewMode.previousAccessibilityLabel)

                                    Text(scheduleDateRangeText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                        .lineLimit(1)

                                    Button {
                                        moveSchedule(by: 1)
                                    } label: {
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(canMoveSchedule(by: 1) ? Color.primary : Color.secondary.opacity(0.35))
                                            .frame(width: 28, height: 28)
                                            .background(Color.white.opacity(0.06), in: Circle())
                                    }
                                    .disabled(canMoveSchedule(by: 1) == false)
                                    .accessibilityLabel(scheduleViewMode.nextAccessibilityLabel)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                
                                Menu {
                                    ForEach(TrainingScheduleViewMode.allCases) { mode in
                                        Button {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                                                scheduleViewMode = mode

                                                if mode == .month,
                                                   let date = weekSessions.first?.date {
                                                    selectedMonthStart = monthStart(for: date)
                                                }
                                            }
                                        } label: {
                                            Label(mode.title, systemImage: scheduleViewMode == mode ? "checkmark" : mode.systemImage)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.down")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.secondary)
                                        
                                        Text(scheduleViewMode == .week ? "Week" : "Month")
                                            .font(.headline)
                                    }
                                    .foregroundStyle(.primary)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 90, alignment: .trailing)
                            }

                            Group {
                                switch scheduleViewMode {
                                case .week:
                                    VStack(spacing: 10) {
                                        ForEach(weekSessions) { session in
                                            NavigationLink {
                                                TrainingSessionDetail(session: session)
                                            } label: {
                                                TrainingWeekRow(
                                                    session: session,
                                                    isToday: Calendar.current.isDateInToday(session.date),
                                                    healthWorkouts: healthWorkouts(on: session.date),
                                                    distanceUnit: distanceUnit
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                case .month:
                                    if let activeMonthStart {
                                        TrainingMonthCalendar(
                                            monthStart: activeMonthStart,
                                            sessions: monthSessions,
                                            healthWorkouts: healthWorkouts(inMonthStartingAt: activeMonthStart)
                                        )
                                    }
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: activeWeekLabel)
                            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: scheduleViewMode)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreatePlanSheet = true
                        Haptics.light()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create Training Plan")
                }
            }
            .sheet(isPresented: $showCreatePlanSheet) {
                CreatePlanSheet(initialInput: initialPlanInput) { planName, input, sessions, replaceFutureSessions, startDate in
                    saveGeneratedPlan(
                        named: planName,
                        input: input,
                        sessions,
                        replaceFutureSessions: replaceFutureSessions,
                        startDate: startDate
                    )
                }
            }
        }
    }

    private var planHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Plans")
                    .font(.headline)
                Spacer()
                if let activePlan {
                    Text(activePlan.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            VStack(spacing: 10) {
                ForEach(trainingPlans) { plan in
                    Button {
                        selectPlan(plan)
                    } label: {
                        PlanHistoryCard(
                            plan: plan,
                            sessions: sessions(for: plan),
                            isSelected: activePlan?.id == plan.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var activePlan: TrainingPlan? {
        if let selectedPlanID,
           let selected = trainingPlans.first(where: { $0.id == selectedPlanID }) {
            return selected
        }

        return defaultPlan
    }

    private var defaultPlan: TrainingPlan? {
        let today = Calendar.current.startOfDay(for: Date())

        if let plan = trainingPlans.first(where: { plan in
            trainingSessions.contains { session in
                session.planID == plan.id && session.date >= today
            }
        }) {
            return plan
        }

        return trainingPlans.first
    }

    private var activeTrainingSessions: [TrainingSession] {
        guard let activePlan else {
            return trainingSessions
        }

        return trainingSessions.filter { $0.planID == activePlan.id }
    }

    private var todaysSession: TrainingSession? {
        activeTrainingSessions.first { Calendar.current.isDateInToday($0.date) }
    }

    private var nextSession: TrainingSession? {
        let today = Calendar.current.startOfDay(for: Date())
        return activeTrainingSessions.first { $0.date >= today }
    }

    private var todaysHealthWorkouts: [HealthWorkout] {
        visibleHealthWorkouts.filter { Calendar.current.isDateInToday($0.startDate) }
    }

    private var visibleHealthWorkouts: [HealthWorkout] {
        healthUseWorkouts ? healthWorkouts : []
    }

    private var initialPlanInput: PlanSetupInput {
        var input = PlanSetupInput()
        input.readiness = recommendedPlanReadiness
        return input
    }

    private var recommendedPlanReadiness: TrainingPlanReadiness {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lookbackStart = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let recentSessions = trainingSessions.filter { session in
            session.date >= lookbackStart && session.date < today && isRestSession(session) == false
        }

        guard recentSessions.isEmpty == false else { return .steady }

        let missedCount = recentSessions.filter { $0.isCompleted == false }.count
        let completedCount = recentSessions.filter(\.isCompleted).count
        let hardCount = recentSessions.filter { $0.effortRating == "Hard" }.count

        if missedCount >= 2 || hardCount >= 2 {
            return .recovery
        }

        if completedCount >= max(3, recentSessions.count - 1) {
            return .build
        }

        return .steady
    }

    private var weekSessions: [TrainingSession] {
        guard let label = activeWeekLabel else { return [] }
        return activeTrainingSessions
            .filter { $0.weekLabel == label }
            .sorted { $0.date < $1.date }
    }

    private var monthSessions: [TrainingSession] {
        guard let activeMonthStart else { return [] }
        return activeTrainingSessions
            .filter { monthStart(for: $0.date) == activeMonthStart }
            .sorted { $0.date < $1.date }
    }

    private var visibleSessions: [TrainingSession] {
        switch scheduleViewMode {
        case .week:
            weekSessions
        case .month:
            monthSessions
        }
    }

    private var activeWeekLabel: String? {
        if let selectedWeekLabel,
           weekLabels.contains(selectedWeekLabel) {
            return selectedWeekLabel
        }

        return currentWeekLabel ?? nextSession?.weekLabel ?? weekLabels.first
    }

    private var currentWeekLabel: String? {
        todayWeekTargetLabel
    }

    // TODO: This variable is now unnecessary, remove anything that only this used
//    private var scheduleSectionTitle: String {
//        switch scheduleViewMode {
//        case .week:
//            guard let activeWeekLabel else { return "Week" }
//            return activeWeekLabel == currentWeekLabel ? "Week" : "Week"
//        case .month:
//            guard let activeMonthStart,
//                  let currentMonthStart else { return "Month" }
//            return activeMonthStart == currentMonthStart ? "Month" : "Month"
//        }
//    }

    private var weekLabels: [String] {
        Dictionary(grouping: activeTrainingSessions, by: \.weekLabel)
            .sorted { lhs, rhs in
                let lhsDate = lhs.value.map(\.date).min() ?? .distantFuture
                let rhsDate = rhs.value.map(\.date).min() ?? .distantFuture
                return lhsDate < rhsDate
            }
            .map(\.key)
    }

    private var monthStarts: [Date] {
        Array(Set(activeTrainingSessions.map { monthStart(for: $0.date) }))
            .sorted()
    }

    private var activeMonthStart: Date? {
        if let selectedMonthStart,
           monthStarts.contains(selectedMonthStart) {
            return selectedMonthStart
        }

        return currentMonthStart ?? (todaysSession ?? nextSession).map { monthStart(for: $0.date) } ?? monthStarts.first
    }

    private var currentMonthStart: Date? {
        if monthStarts.contains(todayMonthStart) {
            return todayMonthStart
        }

        return nil
    }

    private var todayMonthStart: Date {
        monthStart(for: Date())
    }

    private var todayWeekTargetLabel: String? {
        if let todaysSession {
            return todaysSession.weekLabel
        }

        guard let todayWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else {
            return nil
        }

        return activeTrainingSessions.first { todayWeek.contains($0.date) }?.weekLabel
    }

    private var scheduleDateRangeText: String {
        switch scheduleViewMode {
        case .week:
            guard let firstDate = weekSessions.first?.date,
                  let lastDate = weekSessions.last?.date else { return "" }
            return formattedDateRange(from: firstDate, to: lastDate)
        case .month:
            guard let activeMonthStart,
                  let monthInterval = Calendar.current.dateInterval(of: .month, for: activeMonthStart),
                  let lastDate = Calendar.current.date(byAdding: .day, value: -1, to: monthInterval.end) else { return "" }
            return formattedDateRange(from: activeMonthStart, to: lastDate)
        }
    }

    private func formattedDateRange(from firstDate: Date, to lastDate: Date) -> String {
        let calendar = Calendar.current
        let sameMonth = calendar.component(.month, from: firstDate) == calendar.component(.month, from: lastDate)
        let sameYear = calendar.component(.year, from: firstDate) == calendar.component(.year, from: lastDate)

        if sameMonth && sameYear {
            let month = firstDate.formatted(.dateTime.month(.abbreviated))
            let firstDay = firstDate.formatted(.dateTime.day())
            let lastDay = lastDate.formatted(.dateTime.day())
            return "\(month) \(firstDay)-\(lastDay)"
        }

        return "\(firstDate.formatted(.dateTime.month(.abbreviated).day()))-\(lastDate.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var canJumpToTodaySchedule: Bool {
        switch scheduleViewMode {
        case .week:
            guard let currentWeekLabel else { return false }
            return activeWeekLabel != currentWeekLabel
        case .month:
            guard let currentMonthStart else { return false }
            return activeMonthStart != currentMonthStart
        }
    }

    private func canMoveSchedule(by offset: Int) -> Bool {
        switch scheduleViewMode {
        case .week:
            canMoveWeek(by: offset)
        case .month:
            canMoveMonth(by: offset)
        }
    }

    private func canMoveWeek(by offset: Int) -> Bool {
        guard let activeWeekLabel,
              let currentIndex = weekLabels.firstIndex(of: activeWeekLabel) else { return false }

        let nextIndex = currentIndex + offset
        return nextIndex >= 0 && nextIndex < weekLabels.count
    }

    private func canMoveMonth(by offset: Int) -> Bool {
        guard let activeMonthStart,
              let currentIndex = monthStarts.firstIndex(of: activeMonthStart) else { return false }

        let nextIndex = currentIndex + offset
        return nextIndex >= 0 && nextIndex < monthStarts.count
    }

    private func moveSchedule(by offset: Int) {
        switch scheduleViewMode {
        case .week:
            moveWeek(by: offset)
        case .month:
            moveMonth(by: offset)
        }
    }

    private func jumpToTodaySchedule() {
        guard canJumpToTodaySchedule else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            switch scheduleViewMode {
            case .week:
                selectedWeekLabel = currentWeekLabel
            case .month:
                selectedMonthStart = currentMonthStart

                if let currentMonthStart,
                   let firstSession = activeTrainingSessions.first(where: { monthStart(for: $0.date) == currentMonthStart }) {
                    selectedWeekLabel = firstSession.weekLabel
                }
            }
        }

        Haptics.light()
    }

    private func moveWeek(by offset: Int) {
        guard let activeWeekLabel,
              let currentIndex = weekLabels.firstIndex(of: activeWeekLabel) else { return }

        let nextIndex = min(max(currentIndex + offset, 0), weekLabels.count - 1)
        guard nextIndex != currentIndex else { return }

        let nextWeekLabel = weekLabels[nextIndex]
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            selectedWeekLabel = nextWeekLabel

            if let firstSession = activeTrainingSessions.first(where: { $0.weekLabel == nextWeekLabel }) {
                selectedMonthStart = monthStart(for: firstSession.date)
            }
        }

        Haptics.light()
    }

    private func moveMonth(by offset: Int) {
        guard let activeMonthStart,
              let currentIndex = monthStarts.firstIndex(of: activeMonthStart) else { return }

        let nextIndex = min(max(currentIndex + offset, 0), monthStarts.count - 1)
        guard nextIndex != currentIndex else { return }

        let nextMonthStart = monthStarts[nextIndex]
        guard let nextSession = activeTrainingSessions.first(where: { monthStart(for: $0.date) == nextMonthStart }) else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            selectedMonthStart = nextMonthStart
            selectedWeekLabel = nextSession.weekLabel
        }

        Haptics.light()
    }

    private func selectPlan(_ plan: TrainingPlan) {
        let planSessions = sessions(for: plan)
        let todayWeekLabel = weekLabelContainingToday(in: planSessions)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            selectedPlanID = plan.id
            selectedWeekLabel = todayWeekLabel ?? planSessions.first?.weekLabel
            selectedMonthStart = (planSessions.first { Calendar.current.isDateInToday($0.date) } ?? planSessions.first).map { monthStart(for: $0.date) }
        }

        Haptics.light()
    }

    private func sessions(for plan: TrainingPlan) -> [TrainingSession] {
        trainingSessions
            .filter { $0.planID == plan.id }
            .sorted { $0.date < $1.date }
    }

    private func weekLabelContainingToday(in sessions: [TrainingSession]) -> String? {
        guard let todayWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else {
            return nil
        }

        return sessions.first { todayWeek.contains($0.date) }?.weekLabel
    }

    private func isRestSession(_ session: TrainingSession) -> Bool {
        session.segments.contains { segment in
            segment.kind == .rest && segment.priority == .required
        }
    }

    private func healthWorkouts(on date: Date) -> [HealthWorkout] {
        visibleHealthWorkouts.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }

    private func healthWorkouts(inMonthStartingAt monthStartDate: Date) -> [HealthWorkout] {
        visibleHealthWorkouts.filter { monthStart(for: $0.startDate) == monthStartDate }
    }

    private func canMatchTodaysHealthWorkouts(to session: TrainingSession) -> Bool {
        guard session.isCompleted == false else { return false }
        return todaysHealthWorkouts.contains { canApply($0, to: session) }
    }

    private func canApply(_ workout: HealthWorkout, to session: TrainingSession) -> Bool {
        guard Calendar.current.isDate(workout.startDate, inSameDayAs: session.date),
              workout.matchedTrainingSessionID == nil else { return false }

        let workoutKinds = workout.matchingTrainingKinds
        guard workoutKinds.isEmpty == false else { return false }

        return session.segments.contains { segment in
            workoutKinds.contains(segment.kind) && segment.isCompleted == false
        }
    }

    private func matchTodaysHealthWorkouts(to session: TrainingSession) {
        let matchingWorkouts = todaysHealthWorkouts.filter { canApply($0, to: session) }
        guard matchingWorkouts.isEmpty == false else { return }

        var updatedSegments = session.segments
        let workoutKinds = Set(matchingWorkouts.flatMap { $0.matchingTrainingKinds })
        let requiredMatches = updatedSegments.indices.filter { index in
            updatedSegments[index].priority == .required && workoutKinds.contains(updatedSegments[index].kind)
        }
        let matchingIndexes = requiredMatches.isEmpty ? updatedSegments.indices.filter { index in
            workoutKinds.contains(updatedSegments[index].kind)
        } : requiredMatches

        guard matchingIndexes.isEmpty == false else { return }

        matchingIndexes.forEach { index in
            updatedSegments[index].isCompleted = true
        }
        session.segments = updatedSegments

        if session.canComplete {
            session.isCompleted = true
            session.completedAt = Date()
            creditWorkoutHabitIfNeeded(for: session)
        }

        matchingWorkouts.forEach { workout in
            workout.matchedTrainingSessionID = session.id.uuidString
        }

        try? context.save()
        Haptics.success()
    }


    private func creditWorkoutHabitIfNeeded(for session: TrainingSession) {
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

    private func saveGeneratedPlan(
        named planName: String,
        input: PlanSetupInput,
        _ sessions: [TrainingSession],
        replaceFutureSessions: Bool,
        startDate: Date
    ) -> String? {
        let cutoffDate = Calendar.current.startOfDay(for: startDate)
        let sortedSessions = sessions.sorted { $0.date < $1.date }
        guard let firstDate = sortedSessions.first?.date,
              let lastDate = sortedSessions.last?.date else {
            return "This plan does not have any sessions to save."
        }

        let plan = TrainingPlan(
            name: planName,
            startDate: firstDate,
            endDate: lastDate,
            goalTitle: input.goal.title,
            targetTitle: input.planningAnchor == .targetDate ? input.eventTarget.title : nil,
            weekCount: input.weekCount,
            scheduledMinutes: sortedSessions.reduce(0) { $0 + $1.scheduledMinutes },
            estimatedLoad: sortedSessions.reduce(0) { $0 + $1.estimatedLoad }
        )

        sortedSessions.forEach { session in
            session.planID = plan.id
            session.planName = plan.name
        }

        do {
            try context.transaction {
                if replaceFutureSessions {
                    trainingSessions
                        .filter { $0.date >= cutoffDate && $0.isCompleted == false }
                        .forEach { context.delete($0) }
                }

                context.insert(plan)
                sortedSessions.forEach { context.insert($0) }
            }
        } catch {
            context.rollback()
            return error.localizedDescription
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            selectedPlanID = plan.id
            selectedWeekLabel = sortedSessions.first?.weekLabel
            selectedMonthStart = sortedSessions.first.map { monthStart(for: $0.date) }
        }

        return nil
    }

    private func monthStart(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? Calendar.current.startOfDay(for: date)
    }
}
