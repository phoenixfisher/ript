import SwiftUI

struct HomeScoreCard: View {
    var progress: Double
    var completedWins: Int
    var totalWins: Int
    var xp: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Daily Progress")
                        .font(.headline)
                    Text(progressLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text("\(Int(clampedProgress * 100))%")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.green.opacity(0.14), in: Capsule())
            }

            HomeProgressMeter(progress: clampedProgress)

            HStack(spacing: 16) {
                Label("\(completedWins)/\(totalWins) wins", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("\(xp) XP", systemImage: "bolt.fill")
                    .foregroundStyle(.yellow)
                Spacer(minLength: 0)
            }
            .font(.caption)
            .fontWeight(.semibold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var progressLine: String {
        let remainingWins = max(totalWins - completedWins, 0)
        if totalWins == 0 {
            return "No wins planned yet"
        } else if remainingWins == 0 {
            return "All daily wins complete"
        } else if remainingWins == 1 {
            return "1 win left today"
        } else {
            return "\(remainingWins) wins left today"
        }
    }
}

struct HomeProgressMeter: View {
    var progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.11))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint, .blue.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth(in: proxy.size.width))
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: progress)
            }
        }
        .frame(height: 12)
        .accessibilityLabel("Daily progress")
        .accessibilityValue("\(Int(clampedProgress * 100)) percent")
    }

    private func fillWidth(in totalWidth: CGFloat) -> CGFloat {
        guard totalWidth > 0 else { return 0 }
        guard clampedProgress > 0 else { return 0 }
        return max(12, totalWidth * clampedProgress)
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }
}
