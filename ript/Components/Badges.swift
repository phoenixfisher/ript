import SwiftUI

struct StreakBadge: View {
    var count: Int
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill").foregroundStyle(.orange)
            Text("\(count)")
                .font(.title2).bold()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct LevelTag: View {
    var title: String
    var body: some View {
        Text(title)
            .font(.footnote).bold()
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(LinearGradient(colors: [.blue.opacity(0.6), .green.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
    }
}
