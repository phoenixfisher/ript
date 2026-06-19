import SwiftUI
import SwiftData

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
