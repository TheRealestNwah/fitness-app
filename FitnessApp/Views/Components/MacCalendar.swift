#if os(macOS)
import SwiftUI

/// A keyboard-accessible month grid with the same logged-day markers as the iPad calendar.
struct LoggedDaysCalendar: View {
    @Binding var selection: Date
    var loggedDays: Set<Date>
    var onSelect: () -> Void
    @State private var month = Date.now
    private let calendar = Calendar.current

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: month)?.start ?? month.startOfDay
    }

    private var days: [Date?] {
        let offset = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0
        return Array(repeating: nil, count: offset) + (0..<count).map { monthStart.adding(days: $0) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous month")
                Spacer()
                Text(month, format: .dateTime.month(.wide).year()).font(.headline)
                Spacer()
                Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next month")
                    .disabled(calendar.isDate(month, equalTo: .now, toGranularity: .month))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(index + calendar.firstWeekday - 1) % 7])
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        Button {
                            selection = day
                            onSelect()
                        } label: {
                            VStack(spacing: 3) {
                                Text(day, format: .dateTime.day())
                                Circle().fill(loggedDays.contains(day) ? Color.accentColor : .clear)
                                    .frame(width: 4, height: 4)
                            }
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .background(calendar.isDate(day, inSameDayAs: selection) ? Color.accentColor.opacity(0.2) : .clear,
                                        in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .disabled(day > Date.now.startOfDay)
                        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                        .accessibilityValue(loggedDays.contains(day) ? "Food logged" : "No food logged")
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }
        }
        .padding()
        .onChange(of: selection, initial: true) { month = selection }
    }

    private func moveMonth(_ offset: Int) {
        month = calendar.date(byAdding: .month, value: offset, to: monthStart) ?? month
    }
}
#endif
