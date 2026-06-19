import SwiftUI

enum TrainingScheduleViewMode: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            "Week"
        case .month:
            "Month"
        }
    }

    var systemImage: String {
        switch self {
        case .week:
            "calendar"
        case .month:
            "calendar.badge.clock"
        }
    }

    var previousAccessibilityLabel: String {
        switch self {
        case .week:
            "Previous Week"
        case .month:
            "Previous Month"
        }
    }

    var nextAccessibilityLabel: String {
        switch self {
        case .week:
            "Next Week"
        case .month:
            "Next Month"
        }
    }
}

struct TrainingMonthCalendar: View {
    var monthStart: Date
    var sessions: [TrainingSession]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(calendarDays) { day in
                    if let date = day.date {
                        if let session = day.sessions.first {
                            NavigationLink {
                                TrainingSessionDetail(session: session)
                            } label: {
                                TrainingCalendarDayCell(date: date, sessions: day.sessions)
                            }
                            .buttonStyle(.plain)
                        } else {
                            TrainingCalendarDayCell(date: date, sessions: day.sessions)
                        }
                    } else {
                        Color.clear
                            .frame(height: 58)
                    }
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let startIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private var calendarDays: [TrainingCalendarDay] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let leadingBlankCount = leadingBlankDays(for: monthStart)
        var days = (0..<leadingBlankCount).map { index in
            TrainingCalendarDay(id: "blank-\(index)", date: nil, sessions: [])
        }

        days += dayRange.compactMap { day -> TrainingCalendarDay? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { return nil }
            let daySessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
            return TrainingCalendarDay(
                id: "day-\(date.timeIntervalSinceReferenceDate)",
                date: date,
                sessions: daySessions
            )
        }

        let trailingBlankCount = (7 - days.count % 7) % 7
        days += (0..<trailingBlankCount).map { index in
            TrainingCalendarDay(id: "trailing-blank-\(index)", date: nil, sessions: [])
        }

        return days
    }

    private func leadingBlankDays(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
}

struct TrainingCalendarDay: Identifiable {
    let id: String
    let date: Date?
    let sessions: [TrainingSession]
}

struct TrainingCalendarWorkoutDot: Identifiable {
    let id: UUID
    let kind: TrainingSegmentKind
    let isCompleted: Bool
}

struct TrainingCalendarDayCell: View {
    var date: Date
    var sessions: [TrainingSession]

    private var calendar: Calendar {
        Calendar.current
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var workoutDots: [TrainingCalendarWorkoutDot] {
        sessions.flatMap { session in
            session.segments.map { segment in
                TrainingCalendarWorkoutDot(
                    id: segment.id,
                    kind: segment.kind,
                    isCompleted: segment.isCompleted
                )
            }
        }
    }

    private var isSessionComplete: Bool {
        sessions.isEmpty == false && sessions.allSatisfy(\.isCompleted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(date.formatted(.dateTime.day()))
                .font(.caption.weight(isToday ? .bold : .semibold))
                .foregroundStyle(Color.primary)
                .monospacedDigit()
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 7, maximum: 7), spacing: 4, alignment: .leading)],
                alignment: .leading,
                spacing: 3
            ) {
                ForEach(workoutDots) { dot in
                    Circle()
                        .fill(dot.isCompleted ? dot.kind.tint : Color.clear)
                        .stroke(dot.kind.tint, lineWidth: 1.5)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 8, alignment: .leading)
        }
        .padding(7)
        .frame(height: 58)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cellBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if isSessionComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.green)
                    .padding(7)
            }
        }
    }

    private var cellBackground: Color {
        if isToday {
            return .green.opacity(0.2)
        }

        return sessions.isEmpty ? Color.white.opacity(0.04) : Color.white.opacity(0.08)
    }
}
