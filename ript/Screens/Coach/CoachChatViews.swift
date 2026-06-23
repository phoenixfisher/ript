import SwiftUI

struct CoachDisplayMessage: Identifiable {
    let id: UUID
    let role: String
    let content: String
}
struct AskCoachCard: View {
    @Binding var question: String
    var suggestions: [String]
    var onSubmit: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask Coach")
                .font(.headline)

            HStack(spacing: 10) {
                TextField("Ask about training, meals, recovery...", text: $question)
                    .submitLabel(.done)
                    .onSubmit { Keyboard.dismiss() }
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                Button {
                    onSubmit(nil)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(Color.green, in: Circle())
                }
                .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            onSubmit(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct CoachComposerBar: View {
    @Binding var question: String
    @FocusState private var isFocused: Bool
    var suggestions: [String]
    var onSubmit: (String?) -> Void
    var onFocusChange: (Bool) -> Void = { _ in }
    var sendInvalid: Bool {
        question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if suggestions.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                onSubmit(suggestion)
                            } label: {
                                Text(suggestion)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.white.opacity(0.08), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message Coach", text: $question, axis: .vertical)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit { Keyboard.dismiss() }
                    .onChange(of: isFocused) {
                        onFocusChange(isFocused)
                    }
                    .textFieldStyle(.plain)
                    .lineLimit(isFocused ? 6 : 1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))

                Button {
                    onSubmit(nil)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(Color.green.opacity(sendInvalid ? 0.3 : 1), in: Circle())
                }
                .glassEffect()
                .disabled(sendInvalid)
            }
            .padding(.horizontal)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

struct CoachBubble: View {
    var role: String
    var content: String

    private var isUser: Bool {
        role == "user"
    }

    private var bubbleColor: Color {
        isUser ? .green : Color.white.opacity(0.08)
    }

    private var textColor: Color {
        isUser ? .black : .primary
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 20,
                bottomLeading: isUser ? 20 : 6,
                bottomTrailing: isUser ? 6 : 20,
                topTrailing: 20
            ),
            style: .continuous
        )
    }

    private var displayContent: String {
        isUser ? content : content.removingCoachMarkdownSyntax
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 42) }

            Text(displayContent)
                .font(.subheadline)
                .lineSpacing(2)
                .foregroundStyle(textColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleColor, in: bubbleShape)
                .overlay {
                    if isUser == false {
                        bubbleShape
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

            if isUser == false { Spacer(minLength: 42) }
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: .bottom)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.96, anchor: isUser ? .trailing : .leading)),
                removal: .opacity
            )
        )
    }
}

extension String {
    var removingCoachMarkdownSyntax: String {
        var cleaned = replacingOccurrences(of: "\r\n", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")

        let markerReplacements = [
            "**": "",
            "__": "",
            "`": "",
            "### ": "",
            "## ": "",
            "# ": ""
        ]

        for replacement in markerReplacements {
            cleaned = cleaned.replacingOccurrences(of: replacement.key, with: replacement.value)
        }

        return cleaned
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                String(line).replacingOccurrences(
                    of: #"^\s*[-*]\s+"#,
                    with: "",
                    options: .regularExpression
                )
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct CoachTypingBubble: View {
    @State private var animateDots = false

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(animateDots ? 1 : 0.62)
                        .opacity(animateDots ? 1 : 0.35)
                        .animation(
                            .easeInOut(duration: 0.58)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: animateDots
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 18)
            .background(
                Color.white.opacity(0.08),
                in: UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 20, bottomLeading: 6, bottomTrailing: 20, topTrailing: 20),
                    style: .continuous
                )
            )
            .onAppear {
                animateDots = true
            }

            Spacer(minLength: 42)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
