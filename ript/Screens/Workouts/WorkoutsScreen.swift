import SwiftUI
import SwiftData

struct WorkoutsScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingPlan.createdAt, order: .reverse) private var trainingPlans: [TrainingPlan]
    @Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]
    @Query(sort: \Workout.name) private var workouts: [Workout]
    @State private var selectedPlanID: UUID?
    @State private var selectedWeekLabel: String?
    @State private var selectedMonthStart: Date?
    @State private var scheduleViewMode: TrainingScheduleViewMode = .week
    @State private var showCreatePlanSheet = false

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
                                                TrainingWeekRow(session: session, isToday: Calendar.current.isDateInToday(session.date))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                case .month:
                                    if let activeMonthStart {
                                        TrainingMonthCalendar(monthStart: activeMonthStart, sessions: monthSessions)
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
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

private enum TrainingScheduleViewMode: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            "Week"
        case .month:
            "Month"
        }
    }

    var systemImage: String {
        switch self {
        case .week:
            "calendar"
        case .month:
            "calendar.badge.clock"
        }
    }

    var previousAccessibilityLabel: String {
        switch self {
        case .week:
            "Previous Week"
        case .month:
            "Previous Month"
        }
    }

    var nextAccessibilityLabel: String {
        switch self {
        case .week:
            "Next Week"
        case .month:
            "Next Month"
        }
    }
}

private struct TrainingMonthCalendar: View {
    var monthStart: Date
    var sessions: [TrainingSession]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(calendarDays) { day in
                    if let date = day.date {
                        if let session = day.sessions.first {
                            NavigationLink {
                                TrainingSessionDetail(session: session)
                            } label: {
                                TrainingCalendarDayCell(date: date, sessions: day.sessions)
                            }
                            .buttonStyle(.plain)
                        } else {
                            TrainingCalendarDayCell(date: date, sessions: day.sessions)
                        }
                    } else {
                        Color.clear
                            .frame(height: 58)
                    }
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let startIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private var calendarDays: [TrainingCalendarDay] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let leadingBlankCount = leadingBlankDays(for: monthStart)
        var days = (0..<leadingBlankCount).map { index in
            TrainingCalendarDay(id: "blank-\(index)", date: nil, sessions: [])
        }

        days += dayRange.compactMap { day -> TrainingCalendarDay? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { return nil }
            let daySessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
            return TrainingCalendarDay(
                id: "day-\(date.timeIntervalSinceReferenceDate)",
                date: date,
                sessions: daySessions
            )
        }

        let trailingBlankCount = (7 - days.count % 7) % 7
        days += (0..<trailingBlankCount).map { index in
            TrainingCalendarDay(id: "trailing-blank-\(index)", date: nil, sessions: [])
        }

        return days
    }

    private func leadingBlankDays(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
}

private struct TrainingCalendarDay: Identifiable {
    let id: String
    let date: Date?
    let sessions: [TrainingSession]
}

private struct TrainingCalendarWorkoutDot: Identifiable {
    let id: UUID
    let kind: TrainingSegmentKind
    let isCompleted: Bool
}

private struct TrainingCalendarDayCell: View {
    var date: Date
    var sessions: [TrainingSession]

    private var calendar: Calendar {
        Calendar.current
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var workoutDots: [TrainingCalendarWorkoutDot] {
        sessions.flatMap { session in
            session.segments.map { segment in
                TrainingCalendarWorkoutDot(
                    id: segment.id,
                    kind: segment.kind,
                    isCompleted: segment.isCompleted
                )
            }
        }
    }

    private var isSessionComplete: Bool {
        sessions.isEmpty == false && sessions.allSatisfy(\.isCompleted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(date.formatted(.dateTime.day()))
                .font(.caption.weight(isToday ? .bold : .semibold))
                .foregroundStyle(Color.primary)
                .monospacedDigit()
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 7, maximum: 7), spacing: 4, alignment: .leading)],
                alignment: .leading,
                spacing: 3
            ) {
                ForEach(workoutDots) { dot in
                    Circle()
                        .fill(dot.isCompleted ? dot.kind.tint : Color.clear)
                        .stroke(dot.kind.tint, lineWidth: 1.5)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 8, alignment: .leading)
        }
        .padding(7)
        .frame(height: 58)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cellBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if isSessionComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.green)
                    .padding(7)
            }
        }
    }

    private var cellBackground: Color {
        if isToday {
            return .green.opacity(0.2)
        }

        return sessions.isEmpty ? Color.white.opacity(0.04) : Color.white.opacity(0.08)
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

struct PlanHistoryCard: View {
    var plan: TrainingPlan
    var sessions: [TrainingSession]
    var isSelected: Bool

    private var completedCount: Int {
        sessions.filter(\.isCompleted).count
    }

    private var dateRangeText: String {
        "\(plan.startDate.formatted(.dateTime.month(.abbreviated).day()))-\(plan.endDate.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var hoursText: String {
        let hours = Double(plan.scheduledMinutes) / 60
        return hours.formatted(.number.precision(.fractionLength(hours < 10 ? 1 : 0))) + "h"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "calendar")
                    .foregroundStyle(isSelected ? .green : .secondary)

                Text(plan.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Text(dateRangeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            HStack(spacing: 10) {
                Label("\(completedCount)/\(sessions.count)", systemImage: "checkmark.circle")
                Label(hoursText, systemImage: "clock")
                Label("\(plan.estimatedLoad)", systemImage: "gauge.with.dots.needle.67percent")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 210, alignment: .leading)
        .background(isSelected ? Color.green.opacity(0.13) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.green.opacity(0.75) : Color.clear, lineWidth: 1)
        }
    }
}

struct TrainingSessionDetail: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.name) private var workouts: [Workout]
    var session: TrainingSession

    private let effortOptions = ["Easy", "Good", "Hard"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
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

                if relatedWorkouts.isEmpty == false {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Related Workouts")
                            .font(.headline)

                        ForEach(relatedWorkouts) { workout in
                            NavigationLink {
                                WorkoutDetail(workout: workout)
                            } label: {
                                WorkoutLibraryRow(workout: workout)
                            }
                            .buttonStyle(.plain)
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
        .navigationTitle(session.date.formatted(.dateTime.weekday().month().day()))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var relatedWorkouts: [Workout] {
        let linkedNames = Set(session.segments.compactMap(\.linkedWorkoutName))
        guard linkedNames.isEmpty == false else { return [] }
        return workouts.filter { linkedNames.contains($0.name) }
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
                    .frame(maxHeight: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        
                        Text(segment.title)
                            .font(.headline)
                        
                        Spacer()
                        
                        SegmentKindBadge(kind: segment.kind)
                    }

                    Text(segment.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 12) {
                        if let duration = segment.durationMinutes, duration > 0 {
                            Label("\(duration)m", systemImage: "clock")
                        }

                        Label(segment.intensity.title, systemImage: "speedometer")

                        if segment.estimatedLoad > 0 {
                            Label("Load \(segment.estimatedLoad)", systemImage: "gauge.with.dots.needle.67percent")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let linkedWorkoutName = segment.linkedWorkoutName {
                        Label(linkedWorkoutName, systemImage: "dumbbell.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
