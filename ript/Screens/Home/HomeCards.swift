import SwiftUI

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
    var wellnessSection: WellnessSection? = nil
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
