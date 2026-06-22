import SwiftUI
import SwiftData

struct SettingsScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]
    @Query(sort: \CoachMessage.createdAt, order: .reverse) private var coachMessages: [CoachMessage]
    @Query(sort: \CoachConversation.updatedAt, order: .reverse) private var coachConversations: [CoachConversation]
    @Query(sort: \Day.date, order: .reverse) private var days: [Day]
    @Query(sort: \HealthDailySummary.date, order: .reverse) private var healthSummaries: [HealthDailySummary]
    @Query(sort: \HealthWorkout.startDate, order: .reverse) private var healthWorkouts: [HealthWorkout]

    @AppStorage("profileName") private var profileName: String = ""
    @AppStorage("primaryGoal") private var primaryGoal: String = "Tri performance + physique"
    @AppStorage("raceDateLabel") private var raceDateLabel: String = "June 20"
    @AppStorage("strengthFrequency") private var strengthFrequency: String = "2-3x/week"
    @AppStorage("distanceUnit") private var distanceUnit: String = "Miles"
    @AppStorage("bodyUnit") private var bodyUnit: String = "Pounds"
    @AppStorage("currentPlanName") private var currentPlanName: String = "Olympic Triathlon Build"
    @AppStorage("trainingRaceDay") private var trainingRaceDay: String = "June 20"
    @AppStorage("planStrengthRule") private var planStrengthRule: String = "Add strength on lighter endurance days"
    @AppStorage("healthKitIsConnected") private var healthKitIsConnected: Bool = false
    @AppStorage("healthLastSyncAt") private var healthLastSyncAt: Double = 0
    @AppStorage("healthUseWorkouts") private var healthUseWorkouts: Bool = true
    @AppStorage("healthUseSleep") private var healthUseSleep: Bool = true
    @AppStorage("healthUseHRV") private var healthUseHRV: Bool = true
    @AppStorage("healthUseRestingHR") private var healthUseRestingHR: Bool = true
    @AppStorage("healthUseActiveEnergy") private var healthUseActiveEnergy: Bool = true
    @AppStorage("healthUseBodyMetrics") private var healthUseBodyMetrics: Bool = true
    @AppStorage("coachUseHealthContext") private var coachUseHealthContext: Bool = true
    @AppStorage("coachUseMealContext") private var coachUseMealContext: Bool = true
    @AppStorage("coachUseWorkoutContext") private var coachUseWorkoutContext: Bool = true
    @AppStorage("coachUseReflectContext") private var coachUseReflectContext: Bool = true
    @AppStorage("workoutReminderEnabled") private var workoutReminderEnabled: Bool = true
    @AppStorage("fuelReminderEnabled") private var fuelReminderEnabled: Bool = false
    @AppStorage("reflectReminderEnabled") private var reflectReminderEnabled: Bool = true
    @AppStorage("streakReminderEnabled") private var streakReminderEnabled: Bool = false
    @AppStorage("activeCoachConversationID") private var activeCoachConversationIDString: String = ""
    @State private var showSeededToast = false
    @State private var healthStatusMessage = ""
    @State private var isSyncingHealth = false
    @State private var pendingDestructiveAction: SettingsDestructiveAction?
    @State private var showDestructiveConfirmation = false

    private let primaryGoals = [
        "Tri performance + physique",
        "Visible abs",
        "Consistency",
        "Endurance performance",
        "Strength + definition"
    ]

    private let strengthOptions = [
        "1-2x/week",
        "2-3x/week",
        "3-4x/week"
    ]

    private let strengthRules = [
        "Add strength on lighter endurance days",
        "Core after swims/runs only",
        "Strength only when recovery is green",
        "Keep strength optional during race week"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsSectionCard(
                    title: "Profile & Goals",
                    systemImage: "person.crop.circle.fill",
                    tint: .green
                ) {
                    TextField("Nickname", text: $profileName)
                        .submitLabel(.done)
                        .onSubmit { Keyboard.dismiss() }
                        .textFieldStyle(.roundedBorder)

                    Picker("Main goal", selection: $primaryGoal) {
                        ForEach(primaryGoals, id: \.self) { goal in
                            Text(goal).tag(goal)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("Race date", text: $raceDateLabel)
                        .submitLabel(.done)
                        .onSubmit { Keyboard.dismiss() }
                        .textFieldStyle(.roundedBorder)

                    Picker("Strength/core", selection: $strengthFrequency) {
                        ForEach(strengthOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Distance", selection: $distanceUnit) {
                        Text("Miles").tag("Miles")
                        Text("Kilometers").tag("Kilometers")
                    }
                    .pickerStyle(.segmented)

                    Picker("Body", selection: $bodyUnit) {
                        Text("Pounds").tag("Pounds")
                        Text("Kilograms").tag("Kilograms")
                    }
                    .pickerStyle(.segmented)
                }

                SettingsSectionCard(
                    title: "Apple Health",
                    systemImage: "heart.fill",
                    tint: .red
                ) {
                    SettingsInfoRow(
                        title: "Status",
                        detail: healthStatusDetail,
                        systemImage: healthStatusIcon,
                        tint: healthStatusTint
                    )

                    Button {
                        Task {
                            await connectAppleHealth()
                        }
                    } label: {
                        Label(healthActionTitle, systemImage: "heart.text.square.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSyncingHealth || HealthKitService.isAvailable == false)

                    SettingsInfoRow(
                        title: "Read-only import",
                        detail: "Workouts, sleep, HRV, resting HR, active energy, and body metrics.",
                        systemImage: "waveform.path.ecg",
                        tint: .red
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Workouts", isOn: $healthUseWorkouts)
                        Toggle("Sleep", isOn: $healthUseSleep)
                        Toggle("HRV", isOn: $healthUseHRV)
                        Toggle("Resting heart rate", isOn: $healthUseRestingHR)
                        Toggle("Active energy", isOn: $healthUseActiveEnergy)
                        Toggle("Body metrics", isOn: $healthUseBodyMetrics)
                    }
                    .font(.subheadline)

                    Text("Selected types are requested from Apple Health and saved locally for Workouts, Wellness, and Coach context.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsSectionCard(
                    title: "Training Plan",
                    systemImage: "calendar.badge.clock",
                    tint: .cyan
                ) {
                    TextField("Current plan name", text: $currentPlanName)
                        .submitLabel(.done)
                        .onSubmit { Keyboard.dismiss() }
                        .textFieldStyle(.roundedBorder)

                    TextField("Race day", text: $trainingRaceDay)
                        .submitLabel(.done)
                        .onSubmit { Keyboard.dismiss() }
                        .textFieldStyle(.roundedBorder)

                    Picker("Strength rule", selection: $planStrengthRule) {
                        ForEach(strengthRules, id: \.self) { rule in
                            Text(rule).tag(rule)
                        }
                    }
                    .pickerStyle(.menu)

                    SettingsInfoRow(
                        title: "Loaded sessions",
                        detail: "\(trainingSessions.count) sessions in the generated plan.",
                        systemImage: "list.bullet.clipboard.fill",
                        tint: .cyan
                    )

                    Button {
                    } label: {
                        Label("Re-import or upload plan", systemImage: "square.and.arrow.down.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)

                    Text("Upload support is next. For now, reset the generated plan when you want a clean default plan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(role: .destructive) {
                        requestDestructive(.resetTrainingPlan)
                    } label: {
                        Label("Reset generated plan", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }

                SettingsSectionTitle(title: "Coach")
                CoachAISettingsCard()

                SettingsSectionCard(
                    title: "Coach Context",
                    systemImage: "slider.horizontal.3",
                    tint: .purple
                ) {
                    Toggle("Apple Health", isOn: $coachUseHealthContext)
                    Toggle("Meals and fueling", isOn: $coachUseMealContext)
                    Toggle("Workouts and training plan", isOn: $coachUseWorkoutContext)
                    Toggle("Reflect entries", isOn: $coachUseReflectContext)
                }

                SettingsSectionCard(
                    title: "Notifications",
                    systemImage: "bell.badge.fill",
                    tint: .orange
                ) {
                    Toggle("Morning workout prompt", isOn: $workoutReminderEnabled)
                    Toggle("Midday fuel reminder", isOn: $fuelReminderEnabled)
                    Toggle("Night reflect reminder", isOn: $reflectReminderEnabled)
                    Toggle("Streak/checklist reminder", isOn: $streakReminderEnabled)
                }

                SettingsSectionCard(
                    title: "Data & Privacy",
                    systemImage: "lock.shield.fill",
                    tint: .blue
                ) {
                    SettingsInfoRow(
                        title: "Local app data",
                        detail: "Training, meals, reflections, and coach messages are stored on device.",
                        systemImage: "iphone",
                        tint: .blue
                    )

                    SettingsInfoRow(
                        title: "Health data",
                        detail: "Apple Health access is optional and read-only. Imported summaries stay on this device.",
                        systemImage: "hand.raised.fill",
                        tint: .green
                    )

                    ShareLink(item: exportSummary) {
                        Label("Export summary", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        refreshSeededContent()
                    } label: {
                        Label("Refresh seeded content", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        requestDestructive(.clearCoachMessages)
                    } label: {
                        Label("Clear coach chats (\(coachConversations.count))", systemImage: "message.badge.filled.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .disabled(coachMessages.isEmpty && coachConversations.isEmpty)

                    Button(role: .destructive) {
                        requestDestructive(.clearJournalEntries)
                    } label: {
                        Label("Clear journal entries (\(reflections.count))", systemImage: "book.closed.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .disabled(reflections.isEmpty)

                    Button(role: .destructive) {
                        requestDestructive(.resetAllLocalData)
                    } label: {
                        Label("Delete and reset app data", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)

                    if showSeededToast {
                        Text("Settings action complete.")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }

                SettingsSectionCard(
                    title: "About",
                    systemImage: "info.circle.fill",
                    tint: .secondary
                ) {
                    SettingsInfoRow(
                        title: "Version",
                        detail: appVersion,
                        systemImage: "app.badge.fill",
                        tint: .secondary
                    )

                    SettingsInfoRow(
                        title: "Focus",
                        detail: "Triathlon base training, efficient strength, core work, fueling, and consistency.",
                        systemImage: "scope",
                        tint: .green
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            healthStatusMessage = defaultHealthStatusMessage
        }
        .onChange(of: workoutReminderEnabled) { refreshNotificationSchedule() }
        .onChange(of: fuelReminderEnabled) { refreshNotificationSchedule() }
        .onChange(of: reflectReminderEnabled) { refreshNotificationSchedule() }
        .onChange(of: streakReminderEnabled) { refreshNotificationSchedule() }
        .confirmationDialog(
            pendingDestructiveAction?.title ?? "Confirm action",
            isPresented: $showDestructiveConfirmation,
            titleVisibility: .visible
        ) {
            if let action = pendingDestructiveAction {
                Button(action.buttonTitle, role: .destructive) {
                    performDestructive(action)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDestructiveAction = nil
            }
        } message: {
            Text(pendingDestructiveAction?.message ?? "")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    private var healthPreferences: HealthImportPreferences {
        HealthImportPreferences(
            workouts: healthUseWorkouts,
            sleep: healthUseSleep,
            hrv: healthUseHRV,
            restingHeartRate: healthUseRestingHR,
            activeEnergy: healthUseActiveEnergy,
            bodyMetrics: healthUseBodyMetrics
        )
    }

    private var healthStatusDetail: String {
        if healthStatusMessage.isEmpty == false {
            return healthStatusMessage
        }

        return defaultHealthStatusMessage
    }

    private var defaultHealthStatusMessage: String {
        guard HealthKitService.isAvailable else {
            return "Health data is not available on this device."
        }

        guard healthKitIsConnected else {
            return "Not connected yet"
        }

        let summaryCount = healthSummaries.count == 1 ? "1 day imported" : "\(healthSummaries.count) days imported"
        let workoutCount = healthWorkouts.count == 1 ? "1 workout" : "\(healthWorkouts.count) workouts"
        guard let lastHealthSyncDate else {
            return "Connected. \(summaryCount), \(workoutCount)."
        }

        return "Connected. Last sync \(lastHealthSyncDate.formatted(date: .abbreviated, time: .shortened)). \(summaryCount), \(workoutCount)."
    }

    private var healthStatusIcon: String {
        if HealthKitService.isAvailable == false { return "heart.slash.fill" }
        if isSyncingHealth { return "arrow.triangle.2.circlepath" }
        return healthKitIsConnected ? "heart.fill" : "heart.slash.fill"
    }

    private var healthStatusTint: Color {
        if HealthKitService.isAvailable == false { return .secondary }
        if isSyncingHealth { return .orange }
        return healthKitIsConnected ? .green : .secondary
    }

    private var healthActionTitle: String {
        if isSyncingHealth { return "Syncing Apple Health" }
        return healthKitIsConnected ? "Refresh Apple Health" : "Connect Apple Health"
    }

    private var lastHealthSyncDate: Date? {
        healthLastSyncAt > 0 ? Date(timeIntervalSince1970: healthLastSyncAt) : nil
    }

    private var exportSummary: String {
        """
        Ript Settings Export

        Profile
        Name: \(profileName.isEmpty ? "Not set" : profileName)
        Goal: \(primaryGoal)
        Race date: \(raceDateLabel)
        Distance unit: \(distanceUnit)
        Body unit: \(bodyUnit)

        Training Plan
        Plan: \(currentPlanName)
        Race day: \(trainingRaceDay)
        Strength rule: \(planStrengthRule)
        Sessions loaded: \(trainingSessions.count)

        Data Counts
        Days: \(days.count)
        Health summaries: \(healthSummaries.count)
        Health workouts: \(healthWorkouts.count)
        Reflections: \(reflections.count)
        Coach messages: \(coachMessages.count)

        Coach Context
        Health: \(coachUseHealthContext ? "On" : "Off")
        Meals: \(coachUseMealContext ? "On" : "Off")
        Workouts: \(coachUseWorkoutContext ? "On" : "Off")
        Reflect: \(coachUseReflectContext ? "On" : "Off")
        """
    }

    private func refreshNotificationSchedule() {
        Task {
            await NotificationScheduler.requestAuthorization()
            NotificationScheduler.scheduleDailyReminders()
        }
    }

    private func refreshSeededContent() {
        SampleDataSeeder.seed(context: context)
        Haptics.success()
        showActionToast()
    }

    @MainActor
    private func connectAppleHealth() async {
        guard isSyncingHealth == false else { return }

        isSyncingHealth = true
        healthStatusMessage = "Opening Apple Health permissions..."

        do {
            try await HealthKitService.shared.requestAuthorization(preferences: healthPreferences)
            healthStatusMessage = "Importing recent Apple Health data..."

            let summaries = try await HealthKitService.shared.loadDailySummaries(
                daysBack: 14,
                preferences: healthPreferences
            )
            try HealthSummaryStore.upsert(summaries, in: context)

            let workouts = healthUseWorkouts ? try await HealthKitService.shared.loadHealthWorkouts(daysBack: 14) : []
            try HealthWorkoutStore.upsert(workouts, in: context)

            healthKitIsConnected = true
            healthLastSyncAt = Date().timeIntervalSince1970
            healthStatusMessage = importedHealthStatus(summaries: summaries, workouts: workouts)
            Haptics.success()
        } catch {
            healthStatusMessage = error.localizedDescription
        }

        isSyncingHealth = false
    }

    private func importedHealthStatus(summaries: [HealthDailySummaryValue], workouts: [HealthWorkoutValue]) -> String {
        guard summaries.isEmpty == false || workouts.isEmpty == false else {
            return "Connected, but no samples were returned for the selected types."
        }

        let dayLabel = summaries.count == 1 ? "1 day" : "\(summaries.count) days"
        let workoutLabel = workouts.count == 1 ? "1 workout" : "\(workouts.count) workouts"
        return "Connected. Imported \(dayLabel) and \(workoutLabel)."
    }

    private func requestDestructive(_ action: SettingsDestructiveAction) {
        pendingDestructiveAction = action
        showDestructiveConfirmation = true
    }

    private func performDestructive(_ action: SettingsDestructiveAction) {
        switch action {
        case .resetTrainingPlan:
            SampleDataSeeder.resetTrainingPlan(context: context)
        case .clearCoachMessages:
            coachMessages.forEach { context.delete($0) }
            coachConversations.forEach { context.delete($0) }
            activeCoachConversationIDString = ""
            try? context.save()
        case .clearJournalEntries:
            reflections.forEach { context.delete($0) }
            try? context.save()
        case .resetAllLocalData:
            resetAllLocalData()
        }

        pendingDestructiveAction = nil
        Haptics.success()
        showActionToast()
    }

    private func resetAllLocalData() {
        let dayItems = (try? context.fetch(FetchDescriptor<Day>())) ?? []
        let workoutItems = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        let trainingItems = (try? context.fetch(FetchDescriptor<TrainingSession>())) ?? []
        let reflectionItems = (try? context.fetch(FetchDescriptor<Reflection>())) ?? []
        let bodyMetricItems = (try? context.fetch(FetchDescriptor<BodyMetric>())) ?? []
        let healthSummaryItems = (try? context.fetch(FetchDescriptor<HealthDailySummary>())) ?? []
        let healthWorkoutItems = (try? context.fetch(FetchDescriptor<HealthWorkout>())) ?? []
        let mealItems = (try? context.fetch(FetchDescriptor<MealIdea>())) ?? []
        let badgeItems = (try? context.fetch(FetchDescriptor<Badge>())) ?? []
        let coachConversationItems = (try? context.fetch(FetchDescriptor<CoachConversation>())) ?? []
        let coachMessageItems = (try? context.fetch(FetchDescriptor<CoachMessage>())) ?? []

        dayItems.forEach { context.delete($0) }
        workoutItems.forEach { context.delete($0) }
        trainingItems.forEach { context.delete($0) }
        reflectionItems.forEach { context.delete($0) }
        bodyMetricItems.forEach { context.delete($0) }
        healthSummaryItems.forEach { context.delete($0) }
        healthWorkoutItems.forEach { context.delete($0) }
        mealItems.forEach { context.delete($0) }
        badgeItems.forEach { context.delete($0) }
        coachConversationItems.forEach { context.delete($0) }
        coachMessageItems.forEach { context.delete($0) }
        activeCoachConversationIDString = ""
        healthKitIsConnected = false
        healthLastSyncAt = 0
        healthStatusMessage = defaultHealthStatusMessage

        try? context.save()
        SampleDataSeeder.seed(context: context)
    }

    private func showActionToast() {
        withAnimation {
            showSeededToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSeededToast = false
            }
        }
    }
}
