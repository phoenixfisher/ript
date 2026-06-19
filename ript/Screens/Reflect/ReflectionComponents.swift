import SwiftUI

struct JournalSummaryCard: View {
    var mood: Int
    var result: String
    var tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(summaryTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Mood \(mood)/5")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(result)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(resultTint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(resultTint.opacity(0.14), in: Capsule())
            }

            if tags.isEmpty == false {
                HStack(spacing: 6) {
                    ForEach(tags.prefix(3), id: \.self) { tag in
                        JournalTagLabel(title: tag)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var summaryTitle: String {
        switch mood {
        case 1...2: return "Write it out"
        case 4...5: return "Capture the win"
        default: return "Log the day"
        }
    }

    private var resultTint: Color {
        switch result {
        case "Won": return .green
        case "Missed": return .orange
        default: return .yellow
        }
    }
}

struct MoodPicker: View {
    @Binding var selectedMood: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    selectedMood = value
                    Haptics.light()
                } label: {
                    VStack(spacing: 5) {
                        Text("\(value)")
                            .font(.headline)
                        Text(label(for: value))
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedMood == value ? .black : .primary)
                    .background(selectedMood == value ? Color.green : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func label(for value: Int) -> String {
        switch value {
        case 1: return "Low"
        case 2: return "Heavy"
        case 3: return "Okay"
        case 4: return "Good"
        default: return "Great"
        }
    }
}

struct JournalChoiceButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(isSelected ? .black : .primary)
                .background(isSelected ? Color.green : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct JournalChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .black : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(isSelected ? Color.green : Color.white.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct JournalTextBlock: View {
    var title: String
    var prompt: String
    @Binding var text: String
    var limit: Int
    var lineRange: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(prompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(text.count)/\(limit)")
                    .font(.caption2)
                    .foregroundStyle(text.count >= limit ? .orange : .secondary)
            }

            TextField(prompt, text: $text, axis: .vertical)
                .lineLimit(lineRange)
                .submitLabel(.done)
                .onSubmit { Keyboard.dismiss() }
                .textFieldStyle(.plain)
                .padding()
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct JournalTagLabel: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.green)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.13), in: Capsule())
    }
}

struct RecentReflectionCard: View {
    var reflection: Reflection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(reflection.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 6) {
                    Label("\(reflection.mood)", systemImage: "face.smiling")
                        .labelStyle(.titleAndIcon)
                    Text(reflection.dayResult)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if reflection.win.isEmpty == false {
                Text(reflection.win)
                    .font(.headline)
                    .lineLimit(2)
            } else if reflection.note.isEmpty == false {
                Text(reflection.note)
                    .font(.headline)
                    .lineLimit(2)
            }

            if reflection.tags.isEmpty == false {
                HStack(spacing: 6) {
                    ForEach(reflection.tags.prefix(3), id: \.self) { tag in
                        JournalTagLabel(title: tag)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}
