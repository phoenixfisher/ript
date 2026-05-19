import SwiftUI
import SwiftData

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
