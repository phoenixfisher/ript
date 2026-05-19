import SwiftUI

struct ProgressRing: View {
    var progress: Double // 0...1
    var gradient: Gradient = Gradient(colors: [Color.green, Color.blue])

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
        }
        .frame(width: 120, height: 120)
        .accessibilityLabel("Daily progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}
