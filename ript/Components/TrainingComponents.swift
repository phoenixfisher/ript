import SwiftUI

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
            Text(kind.title)
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
