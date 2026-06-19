import SwiftUI

struct CreatePlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var input: PlanSetupInput
    @State private var planName: String
    @State private var planNameSelection: TextSelection?
    @State private var automaticPlanName: String
    @State private var replaceFutureSessions = true
    @State private var saveErrorMessage: String?
    @State private var step: PlanCreatorStep = .discipline
    @FocusState private var isPlanNameFocused: Bool

    var onSave: (String, PlanSetupInput, [TrainingSession], Bool, Date) -> String?

    private let dailyMinuteOptions = [30, 45, 60, 75, 90, 120]
    private let accent = Color(red: 0.78, green: 1.0, blue: 0.32)

    init(
        initialInput: PlanSetupInput = PlanSetupInput(),
        onSave: @escaping (String, PlanSetupInput, [TrainingSession], Bool, Date) -> String?
    ) {
        let defaultName = "\(initialInput.goal.title) Plan"
        _input = State(initialValue: initialInput)
        _planName = State(initialValue: defaultName)
        _automaticPlanName = State(initialValue: defaultName)
        self.onSave = onSave
    }

    private var generatedSessions: [TrainingSession] {
        TrainingPlanGenerator().generate(input: input)
    }

    private var weeklySummaries: [TrainingWeekSummary] {
        generatedSessions.trainingWeekSummaries
    }

    private var totalScheduledMinutes: Int {
        generatedSessions.reduce(0) { $0 + $1.scheduledMinutes }
    }

    private var totalEstimatedLoad: Int {
        generatedSessions.reduce(0) { $0 + $1.estimatedLoad }
    }

    private var workoutSessionCount: Int {
        generatedSessions.filter { isRestSession($0) == false }.count
    }

    private var restDayCount: Int {
        generatedSessions.filter(isRestSession).count
    }

    private var totalHoursText: String {
        hoursText(for: totalScheduledMinutes)
    }

    private var averageWeeklyHoursText: String {
        guard input.weekCount > 0 else { return "0h" }
        return hoursText(for: totalScheduledMinutes / input.weekCount)
    }

    private var sanitizedPlanName: String {
        planName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        switch step {
        case .discipline:
            return true
        case .target:
            return sanitizedPlanName.isEmpty == false
        case .schedule:
            return input.effectiveTrainingDays.count >= 3
        case .load:
            return true
        case .review:
            return canSave
        }
    }

    private var canSave: Bool {
        sanitizedPlanName.isEmpty == false &&
        input.effectiveTrainingDays.count >= 3 &&
        generatedSessions.isEmpty == false
    }

    private var weeksOfPreparation: Int {
        let start = input.resolvedStartDate()
        let end = input.planningAnchor == .targetDate ? input.targetDate : (generatedSessions.last?.date ?? start)
        let dayCount = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, Int(ceil(Double(dayCount + 1) / 7)))
    }

    private var weeklyHoursBinding: Binding<Double> {
        Binding {
            Double(input.currentWeeklyMinutes) / 60
        } set: { newValue in
            let roundedMinutes = Int((newValue * 60 / 30).rounded()) * 30
            input.currentWeeklyMinutes = min(max(roundedMinutes, 120), 1500)
            updateDailyMinutesFromWeeklyLoad()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            wizardHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    stepContent
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            wizardFooter
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .alert("Plan Could Not Be Saved", isPresented: saveErrorBinding) {
            Button("OK") {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "Try again.")
        }
        .onAppear {
            normalizeGoalSelection()
        }
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding {
            saveErrorMessage != nil
        } set: { isPresented in
            if isPresented == false {
                saveErrorMessage = nil
            }
        }
    }

    private var wizardHeader: some View {
        VStack(spacing: 20) {
            HStack {
                Button {
                    moveBack()
                } label: {
                    Image(systemName: step == .discipline ? "xmark" : "chevron.left")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(step.headerText)
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Color.clear
                    .frame(width: 38, height: 38)
            }

            HStack(spacing: 6) {
                ForEach(PlanCreatorStep.allCases) { progressStep in
                    Capsule()
                        .fill(progressStep.rawValue <= step.rawValue ? accent : Color.white.opacity(0.16))
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .discipline:
            disciplineStep
        case .target:
            targetStep
        case .schedule:
            scheduleStep
        case .load:
            loadStep
        case .review:
            reviewStep
        }
    }

    private var wizardFooter: some View {
        Button {
            continueFromCurrentStep()
        } label: {
            HStack {
                Text(step == .review ? "Generate plan" : "Continue")
                    .font(.headline.weight(.bold))
                Spacer()
                Image(systemName: step == .review ? "checkmark" : "arrow.right")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 24)
            .frame(height: 58)
            .background(canContinue ? accent : Color.white.opacity(0.16), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(step.rawValue >= 2 ? Color.white.opacity(0.88) : Color.clear, lineWidth: 1.5)
            }
        }
        .disabled(canContinue == false)
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private var disciplineStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            PlanStepTitle(kicker: "Configuration", title: "What's your discipline?")

            VStack(spacing: 10) {
                ForEach(disciplineOptions) { option in
                    PlanDisciplineRow(
                        option: option,
                        isSelected: input.goal == option.goal,
                        accent: accent
                    ) {
                        selectGoal(option.goal)
                    }
                }
            }
        }
    }

    private var targetStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            PlanStepTitle(kicker: "Target", title: targetStepTitle)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(targetOptions(for: input.goal)) { target in
                    PlanTargetCard(
                        target: target,
                        isSelected: input.eventTarget == target,
                        accent: accent
                    ) {
                        selectTarget(target)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                PlanFieldLabel("Plan name")
                TextField("Plan name", text: $planName, selection: $planNameSelection)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($isPlanNameFocused)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.09), lineWidth: 1)
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            selectPlanNameText()
                        }
                    )
                    .onChange(of: isPlanNameFocused) { _, isFocused in
                        if isFocused {
                            selectPlanNameText()
                        }
                    }
            }
        }
    }

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            PlanStepTitle(kicker: "Schedule", title: input.planningAnchor == .targetDate ? "When is race day?" : "When should it start?")

            VStack(alignment: .leading, spacing: 10) {
                PlanFieldLabel(input.planningAnchor == .targetDate ? "Race date" : "Start date")
                DatePicker(
                    input.planningAnchor == .targetDate ? "Race date" : "Start date",
                    selection: input.planningAnchor == .targetDate ? $input.targetDate : $input.startDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Text("That's \(weeksOfPreparation) weeks of preparation")
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 12) {
                PlanFieldLabel("Experience level")
                HStack(spacing: 8) {
                    ForEach(TrainingPlanExperience.allCases) { experience in
                        PlanPillButton(
                            title: experience.title,
                            isSelected: input.experience == experience,
                            accent: accent
                        ) {
                            input.experience = experience
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                PlanFieldLabel("Training days")
                HStack(spacing: 8) {
                    ForEach(TrainingPlanWeekday.allCases) { weekday in
                        WizardWeekdayButton(
                            weekday: weekday,
                            isSelected: input.availableWeekdays.contains(weekday),
                            isDisabled: weekday == input.preferredRestDay,
                            accent: accent
                        ) {
                            toggleAvailableDay(weekday)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                PlanMenuTile(title: "Rest day", value: input.preferredRestDay.title) {
                    ForEach(TrainingPlanWeekday.allCases) { weekday in
                        Button(weekday.title) {
                            input.preferredRestDay = weekday
                            input.availableWeekdays.remove(weekday)
                            normalizeLongSessionDay()
                        }
                    }
                }

                PlanMenuTile(title: "Long day", value: input.preferredLongSessionDay.title) {
                    ForEach(input.effectiveTrainingDays) { weekday in
                        Button(weekday.title) {
                            input.preferredLongSessionDay = weekday
                        }
                    }
                }
            }
        }
    }

    private var loadStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            PlanStepTitle(kicker: "Volume", title: "Weekly training load")

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    PlanFieldLabel("Hours per week")
                    Spacer()
                    Text(weeklyHoursBinding.wrappedValue.formatted(.number.precision(.fractionLength(weeklyHoursBinding.wrappedValue.rounded() == weeklyHoursBinding.wrappedValue ? 0 : 1))))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .monospacedDigit()
                    Text("hrs")
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Slider(value: weeklyHoursBinding, in: 2...25, step: 0.5)
                    .tint(accent)

                HStack {
                    Text("2H")
                    Spacer()
                    Text("25H")
                }
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                PlanFieldLabel("Load assessment")
                Text(loadAssessment)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 12) {
                PlanFieldLabel("Readiness")
                HStack(spacing: 8) {
                    ForEach(TrainingPlanReadiness.allCases) { readiness in
                        PlanPillButton(
                            title: readiness.title,
                            isSelected: input.readiness == readiness,
                            accent: accent
                        ) {
                            input.readiness = readiness
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                PlanMenuTile(title: "Session cap", value: "\(input.dailyMinutes)m") {
                    ForEach(dailyMinuteOptions, id: \.self) { minutes in
                        Button("\(minutes)m") {
                            input.dailyMinutes = minutes
                        }
                    }
                }

                PlanMenuTile(title: "Strength", value: input.strengthPriority.title) {
                    ForEach(TrainingStrengthPriority.allCases) { priority in
                        Button(priority.title) {
                            input.strengthPriority = priority
                        }
                    }
                }
            }
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            PlanStepTitle(kicker: "Confirm", title: "Ready to lock it in")

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text(reviewKicker)
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(accent)
                        .textCase(.uppercase)
                    Spacer()
                    if let days = daysUntilTarget {
                        Text("T-\(days)d")
                            .font(.caption2.monospaced().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(sanitizedPlanName)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                    Text(reviewDateText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 0) {
                    PlanReviewMetric(title: "Weeks", value: "\(input.weekCount)")
                    Divider().background(Color.white.opacity(0.14))
                    PlanReviewMetric(title: "Per week", value: averageWeeklyHoursText)
                    Divider().background(Color.white.opacity(0.14))
                    PlanReviewMetric(title: "Total", value: totalHoursText)
                }
                .frame(height: 76)
                .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(spacing: 12) {
                    PlanPhaseRow(marker: "W01-W04", title: "Base", detail: "Aerobic foundation", accent: accent)
                    PlanPhaseRow(marker: "W05-W\(max(input.weekCount - 3, 5))", title: "Build", detail: "Threshold and strength", accent: accent)
                    PlanPhaseRow(marker: "W\(max(input.weekCount - 2, 1))+", title: "Peak -> Taper", detail: input.planningAnchor == .targetDate ? "Race sharpen" : "Benchmark sharpen", accent: accent)
                }

                Toggle("Replace future schedule", isOn: $replaceFutureSessions)
                    .font(.subheadline.weight(.semibold))
                    .tint(accent)
            }
            .padding(24)
            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text("You can adjust workouts after generation.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            if weeklySummaries.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    PlanFieldLabel("First weeks")
                    ForEach(weeklySummaries.prefix(3)) { summary in
                        PlanWeekSummaryRow(summary: summary)
                    }
                }
            }
        }
    }

    private var disciplineOptions: [PlanDisciplineOption] {
        [
            PlanDisciplineOption(goal: .triathlon, title: "Triathlon", subtitle: "Swim + Bike + Run", systemImage: "figure.pool.swim"),
            PlanDisciplineOption(goal: .running, title: "Running", subtitle: "5K to marathon", systemImage: "figure.run"),
            PlanDisciplineOption(goal: .strength, title: "Strength", subtitle: "Lifting benchmark", systemImage: "dumbbell.fill"),
            PlanDisciplineOption(goal: .generalFitness, title: "General Fitness", subtitle: "Balanced conditioning", systemImage: "figure.mixed.cardio")
        ]
    }

    private var targetStepTitle: String {
        switch input.goal {
        case .triathlon:
            return "Pick your race distance"
        case .running:
            return "Pick your running target"
        case .strength:
            return "Pick your strength focus"
        case .generalFitness:
            return "Pick your build"
        }
    }

    private var loadAssessment: String {
        let weeklyHours = weeklyHoursBinding.wrappedValue
        switch weeklyHours {
        case ..<5:
            return "Light training load. Good for consistency, return-to-training, or busy weeks."
        case ..<9:
            return "Moderate training load. Enough volume to build without making recovery complicated."
        case ..<14:
            return "Serious training load. Recovery becomes part of the plan, not optional."
        default:
            return "High training load. This needs disciplined sleep, fueling, and easy days."
        }
    }

    private var reviewKicker: String {
        if input.planningAnchor == .targetDate {
            return "\(input.goal.title)  -  \(input.eventTarget.title)"
        }

        return "\(input.goal.title)  -  Base build"
    }

    private var reviewDateText: String {
        if input.planningAnchor == .targetDate {
            return input.targetDate.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        }

        return input.resolvedStartDate().formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    private var daysUntilTarget: Int? {
        guard input.planningAnchor == .targetDate else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: input.targetDate)
        return Calendar.current.dateComponents([.day], from: today, to: target).day
    }

    private func moveBack() {
        guard let previousStep = step.previous else {
            dismiss()
            return
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            step = previousStep
        }
        Haptics.light()
    }

    private func continueFromCurrentStep() {
        guard canContinue else { return }

        if step == .review {
            savePlan()
            return
        }

        guard let nextStep = step.next else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            step = nextStep
        }
        Haptics.light()
    }

    private func selectGoal(_ goal: TrainingPlanGoal) {
        input.goal = goal
        let target = targetOptions(for: goal).first ?? .baseBuild
        selectTarget(target)
    }

    private func selectTarget(_ target: TrainingEventTarget) {
        input.eventTarget = target
        input.weekCount = target.templateWeekCount
        input.planningAnchor = target == .baseBuild ? .startDate : .targetDate

        let defaultName = defaultPlanName(for: target, goal: input.goal)
        if sanitizedPlanName.isEmpty || planName == automaticPlanName {
            planName = defaultName
        }
        automaticPlanName = defaultName
    }

    private func normalizeGoalSelection() {
        let options = targetOptions(for: input.goal)
        guard options.contains(input.eventTarget) == false else { return }
        selectTarget(options.first ?? .baseBuild)
    }

    private func targetOptions(for goal: TrainingPlanGoal) -> [TrainingEventTarget] {
        switch goal {
        case .triathlon:
            return [.sprintTriathlon, .olympicTriathlon, .halfIronmanTriathlon, .ironmanTriathlon]
        case .running:
            return [.fiveK, .tenK, .halfMarathon, .marathon]
        case .strength:
            return [.strengthBenchmark, .baseBuild]
        case .generalFitness:
            return [.baseBuild, .fiveK, .tenK]
        }
    }

    private func defaultPlanName(for target: TrainingEventTarget, goal: TrainingPlanGoal) -> String {
        switch target {
        case .baseBuild:
            return "\(goal.title) Base Build"
        default:
            return target.title
        }
    }

    private func toggleAvailableDay(_ weekday: TrainingPlanWeekday) {
        guard weekday != input.preferredRestDay else { return }

        if input.availableWeekdays.contains(weekday) {
            guard input.effectiveTrainingDays.count > 3 else { return }
            input.availableWeekdays.remove(weekday)
        } else {
            input.availableWeekdays.insert(weekday)
        }

        normalizeLongSessionDay()
    }

    private func normalizeLongSessionDay() {
        guard input.effectiveTrainingDays.contains(input.preferredLongSessionDay) == false else { return }
        input.preferredLongSessionDay = input.effectiveTrainingDays.first ?? .saturday
    }

    private func updateDailyMinutesFromWeeklyLoad() {
        let dayCount = max(input.effectiveTrainingDays.count, 1)
        let averageMinutes = Double(input.currentWeeklyMinutes) / Double(dayCount)
        let roundedMinutes = Int((averageMinutes / 5).rounded()) * 5
        input.dailyMinutes = min(max(roundedMinutes, 30), 120)
    }

    private func selectPlanNameText() {
        guard planName.isEmpty == false else { return }

        isPlanNameFocused = true
        DispatchQueue.main.async {
            planNameSelection = TextSelection(range: planName.startIndex..<planName.endIndex)
        }
    }

    private func savePlan() {
        let cutoffDate = generatedSessions.first?.date ?? input.resolvedStartDate()
        if let errorMessage = onSave(sanitizedPlanName, input, generatedSessions, replaceFutureSessions, cutoffDate) {
            saveErrorMessage = errorMessage
        } else {
            Haptics.success()
            dismiss()
        }
    }

    private func isRestSession(_ session: TrainingSession) -> Bool {
        session.segments.contains { segment in
            segment.kind == .rest && segment.priority == .required
        }
    }

    private func hoursText(for minutes: Int) -> String {
        let hours = Double(minutes) / 60
        return hours.formatted(.number.precision(.fractionLength(hours < 10 ? 1 : 0))) + "h"
    }
}

private enum PlanCreatorStep: Int, CaseIterable, Identifiable {
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

private struct PlanDisciplineOption: Identifiable {
    let goal: TrainingPlanGoal
    let title: String
    let subtitle: String
    let systemImage: String

    var id: TrainingPlanGoal { goal }
}

private struct PlanStepTitle: View {
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

private struct PlanFieldLabel: View {
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

private struct PlanDisciplineRow: View {
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

private struct PlanTargetCard: View {
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

private struct PlanPillButton: View {
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

private struct WizardWeekdayButton: View {
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

private struct PlanMenuTile<Content: View>: View {
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

private struct PlanReviewMetric: View {
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

private struct PlanPhaseRow: View {
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

private struct PlanWeekSummaryRow: View {
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
