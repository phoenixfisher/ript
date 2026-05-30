import SwiftUI

struct HomeHeader: View {
    var date: Date
    var streak: Int
    var quote: String
    var onRefreshQuote: () -> Void
    @State private var refreshSpin = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                HomeStreakCapsule(streak: streak)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "quote.opening")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding(.top, 3)

                Text(quote)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        refreshSpin += 1
                    }
                    onRefreshQuote()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .rotationEffect(.degrees(Double(refreshSpin) * 360))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh quote")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct HomeStreakCapsule: View {
    var streak: Int

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text(streakText)
                .fontWeight(.semibold)
        }
        .font(.footnote)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.orange.opacity(0.14), in: Capsule())
    }

    private var streakText: String {
        streak == 1 ? "1 day" : "\(streak) days"
    }
}
