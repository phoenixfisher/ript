import SwiftUI

struct CoachConversationHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    var conversations: [CoachConversation]
    var messages: [CoachMessage]
    var activeConversationID: UUID?
    var onSelect: (CoachConversation) -> Void
    var onNewConversation: () -> Void

    private var visibleConversations: [CoachConversation] {
        conversations.filter { messageCount(for: $0) > 0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    onNewConversation()
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(width: 34, height: 34)
                            .background(Color.green, in: Circle())

                        Text("New Coach Chat")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                if visibleConversations.isEmpty {
                    Divider().padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No previous chats")
                            .font(.headline)
                        Text("Coach conversations will show here after you send a message.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(visibleConversations) { conversation in
                        Divider().padding(.horizontal)
                        
                        Button {
                            onSelect(conversation)
                            dismiss()
                        } label: {
                            CoachConversationHistoryRow(
                                conversation: conversation,
                                messageCount: messageCount(for: conversation),
                                isActive: conversation.id == activeConversationID
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Coach Chats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Done") {
                dismiss()
            }
        }
    }

    private func messageCount(for conversation: CoachConversation) -> Int {
        messages.filter { $0.conversationID == conversation.id }.count
    }
}

struct CoachConversationHistoryRow: View {
    var conversation: CoachConversation
    var messageCount: Int
    var isActive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(conversation.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(historyDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }

    private var historyDetail: String {
        let date = conversation.updatedAt.formatted(date: .abbreviated, time: .shortened)
        let countLabel = messageCount == 1 ? "1 message" : "\(messageCount) messages"
        return "\(date) - \(countLabel)"
    }
}
