import SwiftUI
import UIKit

enum Keyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

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

struct ChecklistRow: View {
    var title: String
    var isChecked: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isChecked ? .green : .secondary)
                    .symbolEffect(.bounce, value: isChecked)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct Heatmap: View {
    var values: [Date: Int] // 0..n per day
    var body: some View {
        let days = (0..<42).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }.reversed()
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(16), spacing: 4), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { d in
                let v = values[Calendar.current.startOfDay(for: d)] ?? 0
                Rectangle()
                    .fill(Color.green.opacity(min(0.1 + Double(v) * 0.2, 1)))
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }
}

extension TrainingSegmentKind {
    var title: String {
        switch self {
        case .swim: return "Swim"
        case .bike: return "Bike"
        case .run: return "Run"
        case .brick: return "Brick"
        case .core: return "Core"
        case .strength: return "Strength"
        case .mobility: return "Mobility"
        case .rest: return "Rest"
        }
    }

    var systemImage: String {
        switch self {
        case .swim: return "figure.pool.swim"
        case .bike: return "bicycle"
        case .run: return "figure.run"
        case .brick: return "arrow.triangle.2.circlepath"
        case .core: return "figure.core.training"
        case .strength: return "dumbbell.fill"
        case .mobility: return "figure.flexibility"
        case .rest: return "bed.double.fill"
        }
    }

    var tint: Color {
        switch self {
        case .swim: return .cyan
        case .bike: return .orange
        case .run: return .green
        case .brick: return .mint
        case .core: return .purple
        case .strength: return .red
        case .mobility: return .yellow
        case .rest: return .blue
        }
    }
}

extension TrainingSegmentPriority {
    var title: String {
        switch self {
        case .required: return "Required"
        case .recommended: return "Recommended"
        case .optional: return "Optional"
        }
    }
}

struct SegmentKindBadge: View {
    var kind: TrainingSegmentKind
    var priority: TrainingSegmentPriority?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: kind.systemImage)
                .font(.caption)
            Text(priority?.title ?? kind.title)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(kind.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(kind.tint.opacity(0.14), in: Capsule())
    }
}

struct SetDots: View {
    var count: Int
    var completed: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Image(systemName: index < completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(index < completed ? .green : .secondary)
            }
        }
        .font(.caption)
    }
}
