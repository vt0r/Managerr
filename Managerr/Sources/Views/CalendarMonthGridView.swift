import SwiftUI

struct CalendarMonthGridView: View {
    let monthStart: Date
    let markedDays: Set<Date>
    let selectedWeekStart: Date
    let onWeekSelect: (Date) -> Void
    let onMonthShift: (Int) -> Void

    private var weeks: [[Date]] {
        let cal = Calendar.current
        let offset = (cal.component(.weekday, from: monthStart) - cal.firstWeekday + 7) % 7
        let gridStart = cal.date(byAdding: .day, value: -offset, to: monthStart)!
        return (0..<6).compactMap { w in
            let start = cal.date(byAdding: .day, value: w * 7, to: gridStart)!
            let week = (0..<7).map { cal.date(byAdding: .day, value: $0, to: start)! }
            return week.contains { cal.isDate($0, equalTo: monthStart, toGranularity: .month) } ? week : nil
        }
    }

    private static var weekdayLabels: [String] {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayHeader
            ForEach(0..<weeks.count, id: \.self) { i in
                CalendarWeekRow(
                    week: weeks[i],
                    markedDays: markedDays,
                    monthStart: monthStart,
                    selectedWeekStart: selectedWeekStart
                ) {
                    onWeekSelect(weeks[i][0])
                }
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { onMonthShift(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 36)
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(monthStart, format: .dateTime.month(.wide).year())
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button { onMonthShift(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 36)
            }
            .accessibilityLabel("Next month")
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.weekdayLabels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 4)
    }
}

struct CalendarWeekRow: View {
    let week: [Date]
    let markedDays: Set<Date>
    let monthStart: Date
    let selectedWeekStart: Date
    let onTap: () -> Void

    private var isSelected: Bool {
        Calendar.current.isDate(week[0], equalTo: selectedWeekStart, toGranularity: .weekOfYear)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(week, id: \.self) { date in
                CalendarDayCell(
                    date: date,
                    isMarked: markedDays.contains(Calendar.current.startOfDay(for: date)),
                    isCurrentMonth: Calendar.current.isDate(date, equalTo: monthStart, toGranularity: .month)
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weekAccessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var weekAccessibilityLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let start = fmt.string(from: week[0])
        let end = fmt.string(from: week[6])
        let marked = week.filter { markedDays.contains(Calendar.current.startOfDay(for: $0)) }.count
        return "\(isSelected ? "Selected week" : "Week") \(start)–\(end)\(marked > 0 ? ", \(marked) release\(marked == 1 ? "" : "s")" : "")"
    }
}

struct CalendarDayCell: View {
    let date: Date
    let isMarked: Bool
    let isCurrentMonth: Bool

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        VStack(spacing: 3) {
            Text(date, format: .dateTime.day())
                .font(.caption.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? .white : (isCurrentMonth ? .primary : .secondary))
                .frame(width: 28, height: 28)
                .background(isToday ? Color.accentColor : Color.clear, in: Circle())

            Circle()
                .fill(isMarked ? Color.accentColor : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
        .opacity(isCurrentMonth ? 1 : 0.3)
    }
}
