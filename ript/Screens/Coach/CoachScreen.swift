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
    @Query(sort: \HealthDailySummary.date, order: .reverse) private var healthSummaries: [HealthDailySummary]
    @Query(sort: \MealIdea.title) private var meals: [MealIdea]
    @State private var question: String = ""
    @State private var isWaitingForAI: Bool = false
    @AppStorage("coachSuggestedMessagesEnabled") private var suggestedMessagesEnabled: Bool = true
    @AppStorage("coachUseHealthContext") private var coachUseHealthContext: Bool = true
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
            ZStack(alignment: .bottom) {
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
                        .padding(.bottom, 44)
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

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewConversation()
                        Haptics.light()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(isWaitingForAI)
                    .accessibilityLabel("New Coach Chat")
                }
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
        let todaysHealthSummary = coachUseHealthContext ? healthSummaries.first { Calendar.current.isDate($0.date, inSameDayAs: today) } : nil
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
            todaysHealthSummary: todaysHealthSummary,
            weekSessions: weekSessions,
            fuelProfile: fuelProfile,
            mealPlan: mealPlan
        )
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

#Preview {
    CoachScreen()
        .modelContainer(
            for: [
                Day.self,
                Workout.self,
                TrainingPlan.self,
                TrainingSession.self,
                Reflection.self,
                BodyMetric.self,
                HealthDailySummary.self,
                HealthWorkout.self,
                MealIdea.self,
                Badge.self,
                CoachConversation.self,
                CoachMessage.self
            ],
            inMemory: true
        )
        .preferredColorScheme(.dark)
}
