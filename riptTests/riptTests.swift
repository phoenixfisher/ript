import Foundation
import Testing
@testable import ript

struct TrainingPlanGeneratorTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    @Test func placesLongSessionsOnPreferredLongDayAndKeepsRestDayClear() {
        var input = PlanSetupInput()
        input.goal = .running
        input.startDate = date(year: 2026, month: 6, day: 15)
        input.weekCount = 4
        input.availableWeekdays = [.monday, .wednesday, .saturday]
        input.preferredRestDay = .sunday
        input.preferredLongSessionDay = .saturday

        let sessions = TrainingPlanGenerator(calendar: calendar).generate(input: input)
        let longRuns = sessions.filter { $0.title == "Long Run" }
        let restDays = sessions.filter { $0.title == "Rest Day" }

        #expect(sessions.count == 16)
        #expect(longRuns.count == 4)
        #expect(longRuns.allSatisfy { calendar.component(.weekday, from: $0.date) == TrainingPlanWeekday.saturday.calendarWeekday })
        #expect(restDays.count == 4)
        #expect(restDays.allSatisfy { calendar.component(.weekday, from: $0.date) == TrainingPlanWeekday.sunday.calendarWeekday })
    }

    @Test func targetAnchoredPlanEndsWithEventSession() {
        var input = PlanSetupInput()
        input.goal = .triathlon
        input.planningAnchor = .targetDate
        input.targetDate = date(year: 2026, month: 9, day: 20)
        input.weekCount = 6
        input.eventTarget = .olympicTriathlon

        let sessions = TrainingPlanGenerator(calendar: calendar).generate(input: input)
        let finalSession = sessions.last

        #expect(finalSession?.title == "Race Day")
        #expect(finalSession?.segments.first?.kind == .brick)
        #expect(finalSession.map { calendar.isDate($0.date, inSameDayAs: input.targetDate) } == true)
        #expect(sessions.filter { calendar.isDate($0.date, inSameDayAs: input.targetDate) }.count == 1)
    }

    @Test func readinessChangesEstimatedLoad() {
        var recoveryInput = PlanSetupInput()
        recoveryInput.goal = .running
        recoveryInput.startDate = date(year: 2026, month: 6, day: 15)
        recoveryInput.readiness = .recovery

        var buildInput = recoveryInput
        buildInput.readiness = .build

        let generator = TrainingPlanGenerator(calendar: calendar)
        let recoveryLoad = generator.generate(input: recoveryInput).reduce(0) { $0 + $1.estimatedLoad }
        let buildLoad = generator.generate(input: buildInput).reduce(0) { $0 + $1.estimatedLoad }

        #expect(buildLoad > recoveryLoad)
    }

    @Test func generatedSegmentsCarryStructuredMetadataAndWorkoutLinks() {
        var input = PlanSetupInput()
        input.goal = .triathlon
        input.startDate = date(year: 2026, month: 6, day: 15)
        input.weekCount = 4

        let sessions = TrainingPlanGenerator(calendar: calendar).generate(input: input)
        let segments = sessions.flatMap(\.segments)

        #expect(segments.contains { ($0.durationMinutes ?? 0) > 0 })
        #expect(segments.contains { $0.estimatedLoad > 0 })
        #expect(segments.contains { $0.intensity == .hard })
        #expect(segments.contains { $0.linkedWorkoutName == "Strength A" })
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = calendar.timeZone
        return calendar.startOfDay(for: calendar.date(from: components) ?? Date())
    }
}
