import SwiftUI
import SwiftData

struct SettingsScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingSession.date) private var trainingSessions: [TrainingSession]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]
    @Query(sort: \CoachMessage.createdAt, order: .reverse) private var coachMessages: [CoachMessage]
    @Query(sort: \Day.date, order: .reverse) private var days: [Day]

    @AppStorage("profileName") private var profileName: String = ""
    @AppStorage("primaryGoal") private var primaryGoal: String = "Tri performance + physique"
    @AppStorage("raceDateLabel") private var raceDateLabel: String = "June 20"
    @AppStorage("strengthFrequency") private var strengthFrequency: String = "2-3x/week"
    @AppStorage("distanceUnit") private var distanceUnit: String = "Miles"
    @AppStorage("bodyUnit") private var bodyUnit: String = "Pounds"
    @AppStorage("currentPlanName") private var currentPlanName: String = "Olympic Triathlon Build"
    @AppStorage("trainingRaceDay") private var trainingRaceDay: String = "June 20"
    @AppStorage("planStrengthRule") private var planStrengthRule: String = "Add strength on lighter endurance days"
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
    @State private var showSeededToast = false
    @State private var healthStatusMessage = "Not connected yet"
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
                    subtitle: "Keep the app pointed at the way you actually train.",
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
                    subtitle: "Read-only import will make Home, Workouts, Meals, and Coach smarter.",
                    systemImage: "heart.fill",
                    tint: .red
                ) {
                    SettingsInfoRow(
                        title: "Status",
                        detail: healthStatusMessage,
                        systemImage: "heart.slash.fill",
                        tint: .secondary
                    )

                    Button {
                        showHealthComingSoon()
                    } label: {
                        Label("Connect Apple Health", systemImage: "heart.text.square.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)

                    SettingsInfoRow(
                        title: "Planned data",
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

                    Text("These toggles decide what Health data Ript can use after HealthKit is connected. The first implementation should stay read-only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsSectionCard(
                    title: "Training Plan",
                    subtitle: "Manage the base plan and the strength rules layered on top.",
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
                    subtitle: "Choose what the coach is allowed to reference.",
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
                    subtitle: "Use reminders for the moments you actually want nudges.",
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
                    subtitle: "Keep control of what Ript stores and uses.",
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
                        detail: "When added, Health access should be optional and read-only by default.",
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
                        Label("Clear coach messages (\(coachMessages.count))", systemImage: "message.badge.filled.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .disabled(coachMessages.isEmpty)

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
                    subtitle: "Ript is fitness and nutrition guidance, not medical advice.",
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
        .scrollDismissesKeyboard(.interactively)
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

    private func showHealthComingSoon() {
        showHealthStatus("HealthKit connection is ready for the next implementation step.")
    }

    private func showHealthStatus(_ message: String) {
        withAnimation {
            healthStatusMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                healthStatusMessage = "Not connected yet"
            }
        }
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
        let mealItems = (try? context.fetch(FetchDescriptor<MealIdea>())) ?? []
        let badgeItems = (try? context.fetch(FetchDescriptor<Badge>())) ?? []
        let coachMessageItems = (try? context.fetch(FetchDescriptor<CoachMessage>())) ?? []

        dayItems.forEach { context.delete($0) }
        workoutItems.forEach { context.delete($0) }
        trainingItems.forEach { context.delete($0) }
        reflectionItems.forEach { context.delete($0) }
        bodyMetricItems.forEach { context.delete($0) }
        mealItems.forEach { context.delete($0) }
        badgeItems.forEach { context.delete($0) }
        coachMessageItems.forEach { context.delete($0) }

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

enum SettingsDestructiveAction {
    case resetTrainingPlan
    case clearCoachMessages
    case clearJournalEntries
    case resetAllLocalData

    var title: String {
        switch self {
        case .resetTrainingPlan:
            return "Reset generated plan?"
        case .clearCoachMessages:
            return "Clear coach messages?"
        case .clearJournalEntries:
            return "Clear journal entries?"
        case .resetAllLocalData:
            return "Delete and reset app data?"
        }
    }

    var message: String {
        switch self {
        case .resetTrainingPlan:
            return "This replaces the generated training sessions with the default Olympic triathlon plan."
        case .clearCoachMessages:
            return "This removes the current coach chat history from this device."
        case .clearJournalEntries:
            return "This removes all reflect/journal entries from this device."
        case .resetAllLocalData:
            return "This deletes local progress, workouts, meals, journal entries, coach messages, and generated plan data, then reloads the default seeded content."
        }
    }

    var buttonTitle: String {
        switch self {
        case .resetTrainingPlan:
            return "Reset Plan"
        case .clearCoachMessages:
            return "Clear Messages"
        case .clearJournalEntries:
            return "Clear Journal"
        case .resetAllLocalData:
            return "Delete and Reset"
        }
    }
}

struct SettingsSectionTitle: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, 2)
    }
}

struct SettingsSectionCard<Content: View>: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SettingsInfoRow: View {
    var title: String
    var detail: String
    var systemImage: String
    var tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
