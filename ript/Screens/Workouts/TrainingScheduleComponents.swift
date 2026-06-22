import SwiftUI
import SwiftData

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
    var healthWorkouts: [HealthWorkout] = []
    var distanceUnit: String = "Miles"

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

                HealthWorkoutActualLine(workouts: healthWorkouts, distanceUnit: distanceUnit)
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
    @Query(sort: \HealthWorkout.startDate, order: .reverse) private var healthWorkouts: [HealthWorkout]
    @AppStorage("distanceUnit") private var distanceUnit: String = "Miles"
    @AppStorage("healthUseWorkouts") private var healthUseWorkouts: Bool = true
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

                if dayHealthWorkouts.isEmpty == false {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Actual Workouts")
                            .font(.headline)

                        ForEach(dayHealthWorkouts) { workout in
                            HealthWorkoutRow(
                                workout: workout,
                                distanceUnit: distanceUnit,
                                matchedLabel: matchedLabel(for: workout),
                                showsDate: false
                            )
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

    private var dayHealthWorkouts: [HealthWorkout] {
        guard healthUseWorkouts else { return [] }
        return healthWorkouts.filter { Calendar.current.isDate($0.startDate, inSameDayAs: session.date) }
    }

    private func matchedLabel(for workout: HealthWorkout) -> String? {
        workout.matchedTrainingSessionID == session.id.uuidString ? "Matched" : nil
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
