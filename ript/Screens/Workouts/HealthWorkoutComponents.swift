import SwiftUI

struct TodayHealthWorkoutsCard: View {
    var session: TrainingSession?
    var workouts: [HealthWorkout]
    var distanceUnit: String
    var canMatchToPlan: Bool
    var onMatchToPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Detected Today", systemImage: "heart.text.square.fill")
                    .font(.headline)

                Spacer()

                Text(totalDurationText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(workouts.prefix(3)) { workout in
                    HealthWorkoutRow(
                        workout: workout,
                        distanceUnit: distanceUnit,
                        matchedLabel: nil,
                        showsDate: false
                    )
                }
            }

            if workouts.count > 3 {
                Text("+\(workouts.count - 3) more today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if canMatchToPlan {
                Button {
                    onMatchToPlan()
                } label: {
                    Label(matchButtonTitle, systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            } else if let session, session.isCompleted {
                Label("Plan matched", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.red.opacity(0.18), lineWidth: 1)
        }
    }

    private var totalDurationText: String {
        let minutes = workouts.reduce(0) { $0 + $1.durationMinutes }
        return "\(minutes)m total"
    }

    private var matchButtonTitle: String {
        guard let session else { return "Match to Plan" }
        return session.canComplete ? "Match to Plan" : "Apply Matching Segments"
    }
}


struct HealthWorkoutActualLine: View {
    var workouts: [HealthWorkout]
    var distanceUnit: String

    var body: some View {
        if workouts.isEmpty == false {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "heart.text.square.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)

                Text("Actual: \(summaryText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var summaryText: String {
        let parts = workouts.prefix(2).map { workout in
            var item = "\(workout.title) \(workout.durationText)"
            if let distance = workout.distanceText(preferredUnit: distanceUnit) {
                item += " · \(distance)"
            }
            return item
        }

        let suffix = workouts.count > 2 ? " +\(workouts.count - 2)" : ""
        return parts.joined(separator: " / ") + suffix
    }
}

struct HealthWorkoutRow: View {
    var workout: HealthWorkout
    var distanceUnit: String
    var matchedLabel: String?
    var showsDate: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(workout.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let matchedLabel {
                        Text(matchedLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.14), in: Capsule())
                    }
                }

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var iconName: String {
        workout.trainingKind?.systemImage ?? "figure.walk"
    }

    private var tint: Color {
        workout.trainingKind?.tint ?? .red
    }

    private var detailText: String {
        var parts: [String] = []

        if showsDate {
            parts.append(workout.timeText)
        }

        parts.append(workout.durationText)

        if let distance = workout.distanceText(preferredUnit: distanceUnit) {
            parts.append(distance)
        }

        if let energy = workout.energyText {
            parts.append(energy)
        }

        return parts.joined(separator: " | ")
    }
}
