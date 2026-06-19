import SwiftUI

struct WellnessSummaryCard: View {
    var session: TrainingSession?
    var fuelProfile: FuelProfile
    var reflection: Reflection?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.headline)
                Spacer()
                Text(sessionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            WellnessSummaryRow(
                title: "Fuel",
                value: fuelProfile.title,
                systemImage: fuelProfile.systemImage,
                tint: fuelProfile.tint
            )

            WellnessSummaryRow(
                title: "Journal",
                value: journalLabel,
                systemImage: "book.closed.fill",
                tint: journalTint
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var sessionLabel: String {
        session?.requiredSummary ?? "No scheduled workout"
    }

    private var journalLabel: String {
        guard let reflection else { return "Not logged yet" }
        return "Mood \(reflection.mood)/5 · \(reflection.dayResult)"
    }

    private var journalTint: Color {
        guard let reflection else { return .secondary }
        switch reflection.dayResult {
        case "Won": return .green
        case "Missed": return .orange
        default: return .purple
        }
    }
}

struct WellnessSummaryRow: View {
    var title: String
    var value: String
    var systemImage: String
    var tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
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
