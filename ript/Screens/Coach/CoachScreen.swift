import SwiftUI
import SwiftData

struct CoachScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \CoachMessage.createdAt) private var messages: [CoachMessage]
    @Query(sort: \CoachConversation.updatedAt, order: .reverse) private var conversations: [CoachConversation]
    @Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]
    @Query(sort: \Day.date, order: .reverse) private var days: [Day]
    @Query(sort: \MealIdea.title) private var meals: [MealIdea]
    @State private var question: String = ""
    @State private var showCoachMenu: Bool = false
    @State private var isWaitingForAI: Bool = false
    @AppStorage("coachAIEnabled") private var isAIEnabled: Bool = false
    @AppStorage("coachAIModel") private var coachAIModel: String = CoachAIResponseMode.balanced.model
    @AppStorage("coachSuggestedMessagesEnabled") private var suggestedMessagesEnabled: Bool = true
    @State private var hasSavedCoachAIKey: Bool = CoachAIKeychain.hasAPIKey
    @State private var optimisticUserMessage: CoachDisplayMessage?
    @State private var optimisticCoachMessage: CoachDisplayMessage?
    @State private var composerFocusScrollRequest: Int = 0
    @State private var showConversationHistory: Bool = false
    @State private var didSelectHistoricalConversation: Bool = false
    @AppStorage("activeCoachConversationID") private var activeCoachConversationIDString: String = ""

    private let conversationIdleLimit: TimeInterval = 3 * 60 * 60

    private let suggestedQuestions = [
        "Should I do strength today?",
        "What should I eat before training?",
        "How should I adjust if I am tired?",
        "What is my focus tomorrow?"
    ]

    private var activeConversationID: UUID? {
        UUID(uuidString: activeCoachConversationIDString)
    }

    private var activeConversation: CoachConversation? {
        guard let activeConversationID else { return nil }
        return conversations.first { $0.id == activeConversationID }
    }

    private var activeMessages: [CoachMessage] {
        guard let activeConversationID else { return [] }
        return messages.filter { $0.conversationID == activeConversationID }
    }

    private var displayedMessages: [CoachDisplayMessage] {
        var displayMessages = activeMessages.map { message in
            CoachDisplayMessage(id: message.id, role: message.role, content: message.content)
        }

        if let optimisticUserMessage,
           displayMessages.contains(where: { $0.id == optimisticUserMessage.id }) == false {
            displayMessages.append(optimisticUserMessage)
        }

        if let optimisticCoachMessage,
           displayMessages.contains(where: { $0.id == optimisticCoachMessage.id }) == false {
            displayMessages.append(optimisticCoachMessage)
        }

        return displayMessages
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if displayedMessages.isEmpty {
                                CoachBubble(role: "coach", content: CoachBrain.openingBrief(for: coachContext))
                                    .id("opening")
                            } else {
                                ForEach(displayedMessages) { message in
                                    CoachBubble(role: message.role, content: message.content)
                                        .id(message.id)
                                }
                            }

                            if isWaitingForAI {
                                CoachTypingBubble()
                                    .id("typing")
                            }
                        }
                        .padding()
                        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: displayedMessages.count)
                        .animation(.easeInOut(duration: 0.2), value: isWaitingForAI)
                    }
                    .onChange(of: displayedMessages.last?.id) {
                        scrollToLatest(with: proxy)
                    }
                    .onChange(of: isWaitingForAI) {
                        scrollToLatest(with: proxy)
                    }
                    .onChange(of: composerFocusScrollRequest) {
                        scrollToLatest(with: proxy)
                    }
                    .task {
                        scrollToLatest(with: proxy)
                    }
                }

                CoachComposerBar(
                    question: $question,
                    suggestions: suggestedMessagesEnabled ? suggestedQuestions : [],
                    onSubmit: { prompt in
                        submit(prompt)
                    },
                    onFocusChange: handleComposerFocusChange
                )
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showConversationHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .disabled(isWaitingForAI)
                    .accessibilityLabel("Coach Conversation History")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        startNewConversation()
                        Haptics.light()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(isWaitingForAI)
                    .accessibilityLabel("New Coach Chat")

                    Button {
                        refreshCoachAIConnectionState()
                        normalizeCoachAIModel()
                        showCoachMenu = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("AI Coach Settings")
                }
            }
            .sheet(isPresented: $showCoachMenu, onDismiss: refreshCoachAIConnectionState) {
                NavigationStack {
                    CoachAIConnectionSheet(
                        isAIEnabled: $isAIEnabled,
                        model: $coachAIModel,
                        hasSavedKey: $hasSavedCoachAIKey,
                        hasMessages: activeMessages.isEmpty == false,
                        onClearChat: clearCurrentConversation
                    )
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showConversationHistory) {
                NavigationStack {
                    CoachConversationHistorySheet(
                        conversations: conversations,
                        messages: messages,
                        activeConversationID: activeConversationID,
                        onSelect: selectConversation,
                        onNewConversation: startNewConversation
                    )
                }
                .presentationDetents([.medium, .large])
            }
            .task {
                prepareActiveConversation()
            }
            .onChange(of: scenePhase) {
                guard scenePhase == .active else { return }
                prepareActiveConversation()
            }
        }
    }

    private var coachContext: CoachContext {
        let today = Calendar.current.startOfDay(for: Date())
        let todaysSession = trainingSessions.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let nextSession = trainingSessions.first { $0.date >= today }
        let todaysReflection = reflections.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let todaysDay = days.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let anchor = todaysSession ?? nextSession
        let weekSessions = anchor.map { session in
            trainingSessions.filter { $0.weekLabel == session.weekLabel }
        } ?? []
        let fuelProfile = FuelProfile.profile(for: todaysSession ?? nextSession)
        let mealPlan = SuggestedMealPlan.build(meals: meals, profile: fuelProfile, session: todaysSession ?? nextSession)

        return CoachContext(
            todaysSession: todaysSession,
            nextSession: nextSession,
            todaysReflection: todaysReflection,
            todaysDay: todaysDay,
            weekSessions: weekSessions,
            fuelProfile: fuelProfile,
            mealPlan: mealPlan
        )
    }

    private func refreshCoachAIConnectionState() {
        hasSavedCoachAIKey = CoachAIKeychain.hasAPIKey
        if hasSavedCoachAIKey == false {
            isAIEnabled = false
        }
    }

    private func normalizeCoachAIModel() {
        if CoachAIResponseMode.isSupportedModel(coachAIModel) == false {
            coachAIModel = CoachAIResponseMode.balanced.model
        }
    }

    private func prepareActiveConversation() {
        migrateLegacyMessagesIfNeeded()

        if let activeConversation {
            if shouldStartNewConversation(after: activeConversation) && didSelectHistoricalConversation == false {
                startNewConversation()
            }
            return
        }

        guard let latestConversation = conversations.first else {
            startNewConversation()
            return
        }

        if shouldStartNewConversation(after: latestConversation) {
            startNewConversation()
        } else {
            activeCoachConversationIDString = latestConversation.id.uuidString
            didSelectHistoricalConversation = false
        }
    }

    private func migrateLegacyMessagesIfNeeded() {
        let legacyMessages = messages.filter { $0.conversationID == nil }
        guard legacyMessages.isEmpty == false else { return }

        let createdAt = legacyMessages.first?.createdAt ?? Date()
        let updatedAt = legacyMessages.last?.createdAt ?? createdAt
        let conversation = CoachConversation(
            createdAt: createdAt,
            updatedAt: updatedAt,
            title: CoachConversationTitleBuilder.title(for: legacyMessages)
        )

        context.insert(conversation)
        legacyMessages.forEach { $0.conversationID = conversation.id }

        if activeCoachConversationIDString.isEmpty {
            activeCoachConversationIDString = conversation.id.uuidString
        }

        try? context.save()
    }

    private func shouldStartNewConversation(after conversation: CoachConversation) -> Bool {
        let now = Date()
        if Calendar.current.isDate(conversation.updatedAt, inSameDayAs: now) == false {
            return true
        }

        return now.timeIntervalSince(conversation.updatedAt) >= conversationIdleLimit
    }

    private func startNewConversation() {
        activeCoachConversationIDString = ""
        didSelectHistoricalConversation = false
        question = ""
        optimisticUserMessage = nil
        optimisticCoachMessage = nil
    }

    private func selectConversation(_ conversation: CoachConversation) {
        activeCoachConversationIDString = conversation.id.uuidString
        didSelectHistoricalConversation = true
        question = ""
        optimisticUserMessage = nil
        optimisticCoachMessage = nil
    }

    private func clearCurrentConversation() {
        guard let activeConversationID else { return }

        activeMessages.forEach { context.delete($0) }
        if let activeConversation {
            context.delete(activeConversation)
        }

        if UUID(uuidString: activeCoachConversationIDString) == activeConversationID {
            activeCoachConversationIDString = ""
        }

        optimisticUserMessage = nil
        optimisticCoachMessage = nil
        question = ""
        didSelectHistoricalConversation = false
        try? context.save()
    }

    private func conversationForSubmit(prompt: String) -> CoachConversation {
        if let activeConversation {
            if shouldStartNewConversation(after: activeConversation) && didSelectHistoricalConversation == false {
                startNewConversation()
            } else {
                return activeConversation
            }
        }

        let now = Date()
        let conversation = CoachConversation(
            createdAt: now,
            updatedAt: now,
            title: CoachConversationTitleBuilder.title(for: prompt)
        )
        context.insert(conversation)
        activeCoachConversationIDString = conversation.id.uuidString
        didSelectHistoricalConversation = false
        return conversation
    }

    private func submit(_ prompt: String? = nil) {
        let rawQuestion = (prompt ?? question).trimmingCharacters(in: .whitespacesAndNewlines)
        guard rawQuestion.isEmpty == false, isWaitingForAI == false else { return }

        let conversation = conversationForSubmit(prompt: rawQuestion)
        let conversationID = conversation.id
        let currentMessages = messages.filter { $0.conversationID == conversationID }
        let userMessageID = UUID()
        let optimisticMessage = CoachDisplayMessage(id: userMessageID, role: "user", content: rawQuestion)
        let history = currentMessages.suffix(10).map { message in
            CoachTranscriptMessage(role: message.role, content: message.content)
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            question = ""
            optimisticUserMessage = optimisticMessage
            isWaitingForAI = true
        }

        conversation.updatedAt = Date()
        conversation.title = CoachConversationTitleBuilder.title(for: currentMessages, adding: rawQuestion)
        context.insert(CoachMessage(id: userMessageID, role: "user", content: rawQuestion, conversationID: conversationID))
        try? context.save()
        Haptics.light()

        let contextSnapshot = coachContext.promptSnapshot
        let fallback = CoachBrain.answer(rawQuestion, context: coachContext)

        Task {
            let answer = await CoachAIService.answer(
                question: rawQuestion,
                snapshot: contextSnapshot,
                history: history,
                fallback: fallback
            )
            let coachMessageID = UUID()
            let optimisticCoachResponse = CoachDisplayMessage(id: coachMessageID, role: "coach", content: answer)

            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                optimisticCoachMessage = optimisticCoachResponse
                isWaitingForAI = false
            }

            conversation.updatedAt = Date()
            context.insert(CoachMessage(id: coachMessageID, role: "coach", content: answer, conversationID: conversationID))
            try? context.save()
            Haptics.light()
        }
    }

    private func scrollToLatest(with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.24)) {
                if isWaitingForAI {
                    proxy.scrollTo("typing", anchor: .bottom)
                } else if let last = displayedMessages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                } else {
                    proxy.scrollTo("opening", anchor: .bottom)
                }
            }
        }
    }

    private func handleComposerFocusChange(_ isFocused: Bool) {
        guard isFocused else { return }

        DispatchQueue.main.async {
            composerFocusScrollRequest += 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            composerFocusScrollRequest += 1
        }
    }
}

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
                    .padding()
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                if visibleConversations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No previous chats")
                            .font(.headline)
                        Text("Coach conversations will show here after you send a message.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    ForEach(visibleConversations) { conversation in
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
            Image(systemName: isActive ? "checkmark.circle.fill" : "bubble.left.and.bubble.right.fill")
                .font(.headline)
                .foregroundStyle(isActive ? .green : .secondary)
                .frame(width: 34, height: 34)
                .background((isActive ? Color.green : Color.white).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(conversation.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

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
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private var historyDetail: String {
        let date = conversation.updatedAt.formatted(date: .abbreviated, time: .shortened)
        let countLabel = messageCount == 1 ? "1 message" : "\(messageCount) messages"
        return "\(date) - \(countLabel)"
    }
}

private struct CoachDisplayMessage: Identifiable {
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
                    .lineLimit(1...8)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))

                Button {
                    onSubmit(nil)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(Color.green.opacity(sendInvalid ? 0.3 : 1), in: Circle())
                }
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

private extension String {
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

struct CoachAISettingsCard: View {
    @AppStorage("coachAIEnabled") private var isAIEnabled: Bool = false
    @AppStorage("coachAIModel") private var model: String = CoachAIResponseMode.balanced.model
    @State private var hasSavedKey: Bool = CoachAIKeychain.hasAPIKey
    @State private var showConnectionSheet: Bool = false

    var body: some View {
        Button {
            showConnectionSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(width: 30, height: 30)
                
                Text("AI Coach")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.primary)
            }
            .padding()
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI Coach Settings")
        .sheet(isPresented: $showConnectionSheet, onDismiss: refreshConnectionState) {
            NavigationStack {
                CoachAIConnectionSheet(
                    isAIEnabled: $isAIEnabled,
                    model: $model,
                    hasSavedKey: $hasSavedKey
                )
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            refreshConnectionState()
            normalizeModel()
        }
    }

    private func refreshConnectionState() {
        hasSavedKey = CoachAIKeychain.hasAPIKey
        if hasSavedKey == false {
            isAIEnabled = false
        }
    }

    private func normalizeModel() {
        if CoachAIResponseMode.isSupportedModel(model) == false {
            model = CoachAIResponseMode.balanced.model
        }
    }
}

struct CoachAIConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isAIEnabled: Bool
    @Binding var model: String
    @Binding var hasSavedKey: Bool
    var hasMessages: Bool = false
    var onClearChat: (() -> Void)?
    @AppStorage("coachSuggestedMessagesEnabled") private var suggestedMessagesEnabled: Bool = true
    @State private var apiKey: String = ""
    @State private var isConnectionExpanded: Bool = false
    @State private var showConnectionAlert: Bool = false
    @State private var connectionAlertTitle: String = ""
    @State private var connectionAlertMessage: String = ""
    private let savedKeyPlaceholder = "saved-openai-key"

    private var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedMode: CoachAIResponseMode {
        CoachAIResponseMode.mode(for: model)
    }

    private var connectionStatus: String {
        hasSavedKey ? "Saved" : "Missing"
    }

    private var shouldClearConnection: Bool {
        hasSavedKey && (trimmedAPIKey.isEmpty || trimmedAPIKey == savedKeyPlaceholder)
    }

    private var connectionActionTitle: String {
        shouldClearConnection ? "Clear" : "Save"
    }

    private var isConnectionActionDisabled: Bool {
        shouldClearConnection == false && (trimmedAPIKey.isEmpty || trimmedAPIKey == savedKeyPlaceholder)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button {
                    toggleAICoach()
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("AI-Powered Responses", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Toggle("", isOn: $isAIEnabled)
                                .labelsHidden()
                                .disabled(hasSavedKey == false)
                                .allowsHitTesting(false)
                        }

                        if hasSavedKey == false {
                            Text("Add a key to turn AI Coach on.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    suggestedMessagesEnabled.toggle()
                    Haptics.light()
                } label: {
                    HStack {
                        Label("Suggested Messages", systemImage: "text.bubble.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Toggle("", isOn: $suggestedMessagesEnabled)
                            .labelsHidden()
                            .allowsHitTesting(false)
                    }
                    .padding()
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    DisclosureGroup(isExpanded: $isConnectionExpanded) {
                        HStack(spacing: 8) {
                            SecureField("OpenAI API key", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .onSubmit { Keyboard.dismiss() }
                                .textFieldStyle(.roundedBorder)

                            Button {
                                performConnectionAction()
                            } label: {
                                Text(connectionActionTitle)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(width: 48)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .tint(shouldClearConnection ? .red : .green)
                            .disabled(isConnectionActionDisabled)
                        }
                        .padding(.top, 8)
                    } label: {
                        HStack {
                            Label("OpenAI Connection", systemImage: "lock.shield.fill")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(connectionStatus)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(hasSavedKey ? .green : .secondary)
                        }
                    }
                    .tint(.primary)
                }
                .padding()
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                HStack {
                    Label("Response Mode", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Menu {
                        ForEach(CoachAIResponseMode.allCases) { mode in
                            Button {
                                model = mode.model
                            } label: {
                                if mode.model == model {
                                    Label(mode.title, systemImage: "checkmark")
                                } else {
                                    Text(mode.title)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedMode.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                    }
                }
                .padding()
                .frame(minHeight: 58)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                if let onClearChat {
                    Button(role: .destructive) {
                        onClearChat()
                        Haptics.success()
                    } label: {
                        Label("Clear Current Chat", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(!hasMessages)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("AI Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Done") {
                dismiss()
            }
        }
        .alert(connectionAlertTitle, isPresented: $showConnectionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(connectionAlertMessage)
        }
        .onAppear {
            normalizeModel()
            prepareAPIKeyField()
            isConnectionExpanded = hasSavedKey == false
        }
    }

    private func toggleAICoach() {
        guard hasSavedKey else {
            isConnectionExpanded = true
            return
        }

        isAIEnabled.toggle()
        Haptics.light()
    }

    private func saveConnection() {
        guard isConnectionActionDisabled == false else { return }

        CoachAIKeychain.saveAPIKey(trimmedAPIKey)
        hasSavedKey = CoachAIKeychain.hasAPIKey

        if hasSavedKey {
            isAIEnabled = true
            apiKey = savedKeyPlaceholder
            Haptics.success()
            showConnectionConfirmation(
                title: "OpenAI Key Saved",
                message: "AI Coach can use OpenAI when the switch is on."
            )
        }
    }

    private func clearConnection() {
        CoachAIKeychain.deleteAPIKey()
        hasSavedKey = false
        isAIEnabled = false
        apiKey = ""
        Haptics.success()
        showConnectionConfirmation(
            title: "OpenAI Key Cleared",
            message: "AI Coach will use local responses until a new key is saved."
        )
    }

    private func performConnectionAction() {
        if shouldClearConnection {
            clearConnection()
        } else {
            saveConnection()
        }
    }

    private func normalizeModel() {
        if CoachAIResponseMode.isSupportedModel(model) == false {
            model = CoachAIResponseMode.balanced.model
        }
    }

    private func prepareAPIKeyField() {
        if hasSavedKey && apiKey.isEmpty {
            apiKey = savedKeyPlaceholder
        }
    }

    private func showConnectionConfirmation(title: String, message: String) {
        connectionAlertTitle = title
        connectionAlertMessage = message
        showConnectionAlert = true
    }
}

struct CoachContext {
    var todaysSession: TrainingSession?
    var nextSession: TrainingSession?
    var todaysReflection: Reflection?
    var todaysDay: Day?
    var weekSessions: [TrainingSession]
    var fuelProfile: FuelProfile
    var mealPlan: SuggestedMealPlan

    var activeSession: TrainingSession? {
        todaysSession ?? nextSession
    }

    var promptSnapshot: CoachPromptSnapshot {
        CoachPromptSnapshot(
            readiness: readiness.title,
            primarySummary: primarySummary,
            topPriorities: topPriorities,
            guardrails: guardrailRows,
            workoutRows: workoutRows,
            mealRows: mealRows,
            reflectionRows: reflectionRows,
            weekRows: weekRows
        )
    }

    var readiness: CoachReadiness {
        let tags = Set(todaysReflection?.tags ?? [])
        let recoveryTags = Set(["Tired", "Stressed", "Flat", "Needed rest"])
        let mood = todaysReflection?.mood ?? 3

        if mood <= 2 || tags.isDisjoint(with: recoveryTags) == false {
            return .recover
        }

        if hasHardTraining || todaysReflection?.dayResult == "Mixed" || todaysReflection?.dayResult == "Missed" {
            return .hold
        }

        return .push
    }

    var primarySummary: String {
        activeSession?.requiredSummary ?? "No scheduled training found."
    }

    var topPriorities: [String] {
        switch readiness {
        case .push:
            return ["Do the required session", "Add recommended core or strength if it fits", "Keep protein steady"]
        case .hold:
            return ["Do required work first", "Skip optional strength if fatigue climbs", "Fuel before and after training"]
        case .recover:
            return ["Protect recovery", "Keep movement easy unless required", "Prioritize hydration and sleep"]
        }
    }

    var guardrailRows: [String] {
        switch readiness {
        case .push:
            return ["Warm up honestly before adding intensity", "Keep optional work efficient", "Stop add-ons before they threaten tomorrow"]
        case .hold:
            return ["Required training comes before extras", "Skip optional strength if legs feel heavy", "Use carbs around hard or long work"]
        case .recover:
            return ["No extra strength today", "Scale optional core to mobility or skip it", "Hydration and sleep beat more volume"]
        }
    }

    var hasHardTraining: Bool {
        guard let session = activeSession else { return false }
        return session.segments.contains { segment in
            segment.kind == .brick ||
            segment.detail.localizedCaseInsensitiveContains("hard") ||
            segment.detail.localizedCaseInsensitiveContains("tempo") ||
            segment.detail.localizedCaseInsensitiveContains("race pace") ||
            segment.title.localizedCaseInsensitiveContains("90 min") ||
            segment.title.localizedCaseInsensitiveContains("2 hr")
        }
    }

    var hasRecommendedStrength: Bool {
        activeSession?.segments.contains { $0.kind == .strength && $0.priority != .required } ?? false
    }

    var workoutRows: [String] {
        guard let session = activeSession else { return ["No workout scheduled."] }
        return [
            "\(session.date.formatted(date: .abbreviated, time: .omitted)): \(session.title)",
            session.focus,
            "Required: \(session.requiredSummary)",
            "\(session.completedSegmentCount)/\(session.segments.count) items checked"
        ]
    }

    var mealRows: [String] {
        let planned = mealPlan.items.map { item in
            "\(item.title): \(item.meal?.title ?? item.fallbackTitle)"
        }

        return ["Fuel read: \(fuelProfile.title)"] + planned
    }

    var reflectionRows: [String] {
        guard let reflection = todaysReflection else {
            return ["No journal logged today."]
        }

        var rows = [
            "Mood: \(reflection.mood)/5",
            "Result: \(reflection.dayResult)"
        ]

        if reflection.win.isEmpty == false { rows.append("Win: \(reflection.win)") }
        if reflection.obstacle.isEmpty == false { rows.append("Hard moment: \(reflection.obstacle)") }
        if reflection.tomorrowFocus.isEmpty == false { rows.append("Tomorrow: \(reflection.tomorrowFocus)") }
        if reflection.tags.isEmpty == false { rows.append("Tags: \(reflection.tags.joined(separator: ", "))") }
        return rows
    }

    var weekRows: [String] {
        let completed = weekSessions.filter(\.isCompleted).count
        let requiredSegments = weekSessions.flatMap(\.segments).filter { $0.priority == .required }
        let completedRequired = requiredSegments.filter(\.isCompleted).count

        return [
            "Sessions completed: \(completed)/\(weekSessions.count)",
            "Required items checked: \(completedRequired)/\(requiredSegments.count)",
            "Habit wins today: \(todaysDay?.completedHabits.count ?? 0)/\(HabitType.allCases.count)"
        ]
    }
}

enum CoachReadiness {
    case push
    case hold
    case recover

    var title: String {
        switch self {
        case .push: return "Push"
        case .hold: return "Hold"
        case .recover: return "Recover"
        }
    }

    var systemImage: String {
        switch self {
        case .push: return "bolt.fill"
        case .hold: return "pause.circle.fill"
        case .recover: return "leaf.fill"
        }
    }

    var tint: Color {
        switch self {
        case .push: return .green
        case .hold: return .yellow
        case .recover: return .blue
        }
    }
}

enum CoachBrain {
    static func openingBrief(for context: CoachContext) -> String {
        "Today is a \(context.readiness.title.lowercased()) day. \(context.primarySummary) \(context.topPriorities.joined(separator: " "))"
    }

    static func answer(_ question: String, context: CoachContext) -> String {
        let lower = question.lowercased()

        if lower.contains("strength") || lower.contains("core") || lower.contains("abs") {
            return strengthAnswer(context: context)
        }

        if lower.contains("eat") || lower.contains("meal") || lower.contains("fuel") || lower.contains("carb") {
            return mealAnswer(context: context)
        }

        if lower.contains("tired") || lower.contains("sore") || lower.contains("recover") || lower.contains("adjust") || lower.contains("legs") {
            return recoveryAnswer(context: context)
        }

        if lower.contains("tomorrow") || lower.contains("focus") {
            return tomorrowAnswer(context: context)
        }

        if lower.contains("week") || lower.contains("progress") || lower.contains("recap") {
            return weekAnswer(context: context)
        }

        return generalAnswer(context: context)
    }

    private static func strengthAnswer(context: CoachContext) -> String {
        switch context.readiness {
        case .recover:
            return "Skip strength today. Keep the required training easy if you do it, then use mobility or a short walk. Chasing abs while under-recovered usually costs more than it gives."
        case .hold:
            if context.hasRecommendedStrength {
                return "Strength is optional today. Do the required session first, then only lift if your legs feel normal. Keep it 30 minutes, moderate load, and leave reps in reserve."
            }
            return "I would not add strength today. Do the required work, keep core optional, and save lifting for an easier training day."
        case .push:
            return "You can add core or strength today. Keep it efficient: 10-15 minutes of lower abs/core, or 30-40 minutes full-body if it is already recommended in the plan."
        }
    }

    private static func mealAnswer(context: CoachContext) -> String {
        let mealLines = context.mealPlan.items.map { item in
            "\(item.title): \(item.meal?.title ?? item.fallbackTitle)"
        }
        return "Fuel read: \(context.fuelProfile.title). \(context.fuelProfile.guidance.joined(separator: " ")) Suggested plan: \(mealLines.joined(separator: "; "))."
    }

    private static func recoveryAnswer(context: CoachContext) -> String {
        switch context.readiness {
        case .recover:
            return "Make this a recovery-protecting day. Keep required work easy or scaled, skip optional strength, hydrate, and get the journal done tonight so tomorrow has a clear first win."
        case .hold:
            return "Hold the line: complete required work, avoid extra intensity, and use carbs around training. If soreness rises during warmup, drop optional add-ons first."
        case .push:
            return "You look clear to train, but still warm up honestly. If the first 10 minutes feel off, downgrade extras before touching the required session."
        }
    }

    private static func tomorrowAnswer(context: CoachContext) -> String {
        if let focus = context.todaysReflection?.tomorrowFocus, focus.isEmpty == false {
            return "Tomorrow's first win is already set: \(focus). Build the morning around that before adding anything else."
        }

        if let session = context.nextSession {
            return "Tomorrow or the next scheduled session is \(session.title): \(session.requiredSummary). Set one first win tonight, ideally fuel prep or getting the workout started on time."
        }

        return "Set a small first win for tomorrow: protein breakfast, start the workout on time, or get up immediately. Make it concrete enough to check off."
    }

    private static func weekAnswer(context: CoachContext) -> String {
        context.weekRows.joined(separator: " ")
    }

    private static func generalAnswer(context: CoachContext) -> String {
        switch context.readiness {
        case .push:
            return "Push, but keep it clean. Do the required session, add only the recommended extra work, and keep meals protein-forward with carbs around training."
        case .hold:
            return "Hold today. Required training first, optional add-ons second, and fuel the session. This is a day to execute, not prove anything."
        case .recover:
            return "Recover. Reduce optional work, keep food simple and high-protein, hydrate, and prioritize sleep. Consistency includes knowing when not to pile on."
        }
    }
}
