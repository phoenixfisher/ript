import SwiftUI

enum PlanCreatorStep: Int, CaseIterable, Identifiable {
    case discipline
    case target
    case schedule
    case load
    case review

    var id: Int { rawValue }

    var headerText: String {
        "Step \(String(format: "%02d", rawValue + 1)) / \(PlanCreatorStep.allCases.count) - \(title)"
    }

    var title: String {
        switch self {
        case .discipline:
            return "Discipline"
        case .target:
            return "Race"
        case .schedule:
            return "Schedule"
        case .load:
            return "Load"
        case .review:
            return "Review"
        }
    }

    var previous: PlanCreatorStep? {
        PlanCreatorStep(rawValue: rawValue - 1)
    }

    var next: PlanCreatorStep? {
        PlanCreatorStep(rawValue: rawValue + 1)
    }
}

struct PlanDisciplineOption: Identifiable {
    let goal: TrainingPlanGoal
    let title: String
    let subtitle: String
    let systemImage: String

    var id: TrainingPlanGoal { goal }
}

struct PlanStepTitle: View {
    var kicker: String
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kicker)
                .font(.caption2.monospaced().weight(.bold))
                .foregroundStyle(Color(red: 0.78, green: 1.0, blue: 0.32))
                .textCase(.uppercase)
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PlanFieldLabel: View {
    var title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption2.monospaced().weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

struct PlanDisciplineRow: View {
    var option: PlanDisciplineOption
    var isSelected: Bool
    var accent: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: option.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? .black : .primary)
                    .frame(width: 48, height: 48)
                    .background(isSelected ? accent : Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.headline)
                        .foregroundStyle(isSelected ? accent : .primary)
                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? accent : Color.white.opacity(0.25))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? accent.opacity(0.1) : Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? accent : Color.clear, lineWidth: 1.2)
            }
        }
        .buttonStyle(.plain)
    }
}

struct PlanTargetCard: View {
    var target: TrainingEventTarget
    var isSelected: Bool
    var accent: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Text(target.distanceText)
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(target.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSelected ? accent : .primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(target.templateWeekCount)-week template")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
            .background(isSelected ? accent.opacity(0.09) : Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? accent : Color.clear, lineWidth: 1.2)
            }
        }
        .buttonStyle(.plain)
    }
}

struct PlanPillButton: View {
    var title: String
    var isSelected: Bool
    var accent: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? accent : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(isSelected ? accent.opacity(0.1) : Color.white.opacity(0.08), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? accent : Color.clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct WizardWeekdayButton: View {
    var weekday: TrainingPlanWeekday
    var isSelected: Bool
    var isDisabled: Bool
    var accent: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(weekday.shortTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(background, in: Capsule())
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .accessibilityLabel(weekday.title)
    }

    private var foreground: Color {
        if isDisabled {
            return .secondary.opacity(0.45)
        }

        return isSelected ? .black : .primary
    }

    private var background: Color {
        if isDisabled {
            return Color.white.opacity(0.04)
        }

        return isSelected ? accent : Color.white.opacity(0.08)
    }
}

struct PlanMenuTile<Content: View>: View {
    var title: String
    var value: String
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            content
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                PlanFieldLabel(title)
                HStack {
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct PlanReviewMetric: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PlanPhaseRow: View {
    var marker: String
    var title: String
    var detail: String
    var accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(title == "Base" ? Color.white.opacity(0.2) : accent)
                .frame(width: 2, height: 22)
            Text(marker)
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct PlanWeekSummaryRow: View {
    var summary: TrainingWeekSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.weekLabel)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(summary.hoursText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                Label("\(summary.estimatedLoad)", systemImage: "gauge.with.dots.needle.67percent")
                Label("\(summary.hardSessionCount)", systemImage: "bolt.fill")
                Label("\(summary.restDayCount)", systemImage: "bed.double.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(summary.splitText.isEmpty ? "Recovery" : summary.splitText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
