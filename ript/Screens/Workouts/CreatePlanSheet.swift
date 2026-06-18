import SwiftUI

struct CreatePlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var input = PlanSetupInput()
    @State private var replaceFutureSessions = true

    var onSave: ([TrainingSession], Bool, Date) -> Void

    private let weekOptions = [4, 6, 8, 12]
    private let dayOptions = [3, 4, 5, 6]
    private let minuteOptions = [30, 45, 60, 75, 90, 120]

    private var generatedSessions: [TrainingSession] {
        TrainingPlanGenerator().generate(input: input)
    }

    private var workoutSessionCount: Int {
        generatedSessions.filter { isRestSession($0) == false }.count
    }

    private var restDayCount: Int {
        generatedSessions.filter(isRestSession).count
    }

    private var previewSessions: [TrainingSession] {
        let sessions = generatedSessions
        guard let firstWeekLabel = sessions.first?.weekLabel else { return [] }
        return sessions.filter { $0.weekLabel == firstWeekLabel }
    }

    private func isRestSession(_ session: TrainingSession) -> Bool {
        session.segments.contains { segment in
            segment.kind == .rest && segment.priority == .required
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    setupSection
                    previewSummary
                    firstWeekPreview
                }
                .padding()
            }
            .navigationTitle("Create Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePlan()
                    }
                    .disabled(generatedSessions.isEmpty)
                }
            }
        }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plan Setup")
                .font(.headline)

            PlanSettingRow(title: "Goal") {
                Picker("Goal", selection: $input.goal) {
                    ForEach(TrainingPlanGoal.allCases) { goal in
                        Text(goal.title).tag(goal)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PlanSettingRow(title: "Start") {
                DatePicker("Start", selection: $input.startDate, displayedComponents: .date)
                    .labelsHidden()
            }

            PlanSettingRow(title: "Length") {
                Picker("Length", selection: $input.weekCount) {
                    ForEach(weekOptions, id: \.self) { weeks in
                        Text("\(weeks) weeks").tag(weeks)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PlanSettingRow(title: "Days / Week") {
                Picker("Days per week", selection: $input.trainingDaysPerWeek) {
                    ForEach(dayOptions, id: \.self) { days in
                        Text("\(days)").tag(days)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 190)
            }

            PlanSettingRow(title: "Time / Day") {
                Picker("Time per day", selection: $input.dailyMinutes) {
                    ForEach(minuteOptions, id: \.self) { minutes in
                        Text("\(minutes)m").tag(minutes)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PlanSettingRow(title: "Experience") {
                Picker("Experience", selection: $input.experience) {
                    ForEach(TrainingPlanExperience.allCases) { experience in
                        Text(experience.title).tag(experience)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PlanSettingRow(title: "Rest Day") {
                Picker("Rest day", selection: $input.preferredRestDay) {
                    ForEach(TrainingPlanWeekday.allCases) { weekday in
                        Text(weekday.title).tag(weekday)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PlanSettingRow(title: "Strength") {
                Picker("Strength priority", selection: $input.strengthPriority) {
                    ForEach(TrainingStrengthPriority.allCases) { priority in
                        Text(priority.title).tag(priority)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Toggle("Replace future schedule", isOn: $replaceFutureSessions)
                .font(.subheadline.weight(.semibold))
                .tint(.green)
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var previewSummary: some View {
        HStack(spacing: 12) {
            PlanSummaryPill(title: "Workouts", value: "\(workoutSessionCount)", systemImage: "figure.run")
            PlanSummaryPill(title: "Rest", value: "\(restDayCount)", systemImage: "bed.double.fill")
            PlanSummaryPill(title: "Weeks", value: "\(input.weekCount)", systemImage: "calendar")
        }
    }

    private var firstWeekPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("First Week")
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(previewSessions) { session in
                    PlanPreviewRow(session: session)
                }
            }
        }
    }

    private func savePlan() {
        onSave(generatedSessions, replaceFutureSessions, input.startDate)
        Haptics.success()
        dismiss()
    }
}

private struct PlanSettingRow<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            content
                .frame(alignment: .trailing)
        }
    }
}

private struct PlanSummaryPill: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.green)

            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct PlanPreviewRow: View {
    var session: TrainingSession

    private var primarySegment: TrainingSegment? {
        session.segments.first
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(session.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(session.date.formatted(.dateTime.day()))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text(session.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(session.requiredSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let primarySegment {
                Image(systemName: primarySegment.kind.systemImage)
                    .font(.headline)
                    .foregroundStyle(primarySegment.kind.tint)
                    .frame(width: 28, height: 28)
                    .background(primarySegment.kind.tint.opacity(0.14), in: Circle())
            }
        }
        .padding()
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
