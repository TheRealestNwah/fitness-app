import Foundation

/// Weekly calorie banking and scheduled diet breaks.
enum BudgetCalculator {
    /// Today's target when the week is budgeted as a whole: what's left of 7 × the daily
    /// target, shared over the days left (today included). Past days in the week with nothing
    /// logged count as on target, so a forgotten day doesn't turn into a windfall.
    /// Clamped between the safety floor and 150% of the daily target.
    static func weeklyAdjustedTarget(dailyTarget: Int,
                                     intakeByDay: [Date: Double],
                                     floor: Int,
                                     today: Date = .now,
                                     calendar: Calendar = .current) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        guard let week = calendar.dateInterval(of: .weekOfYear, for: todayStart) else { return dailyTarget }
        let pastDays = calendar.dateComponents([.day], from: week.start, to: todayStart).day ?? 0
        var spent = 0.0
        for offset in 0..<pastDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: week.start) else { continue }
            let eaten = intakeByDay[day] ?? 0
            spent += eaten > 0 ? eaten : Double(dailyTarget)
        }
        let remainingDays = max(7 - pastDays, 1)
        let share = (Double(dailyTarget * 7) - spent) / Double(remainingDays)
        let ceiling = Double(dailyTarget) * 1.5
        return Int(min(max(share, Double(floor)), ceiling).rounded())
    }

    /// Calories banked (positive) or overspent (negative) so far this week, against the daily target.
    static func weekBalance(dailyTarget: Int, intakeByDay: [Date: Double], today: Date = .now,
                            calendar: Calendar = .current) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        guard let week = calendar.dateInterval(of: .weekOfYear, for: todayStart) else { return 0 }
        let pastDays = calendar.dateComponents([.day], from: week.start, to: todayStart).day ?? 0
        var balance = 0.0
        for offset in 0..<pastDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: week.start),
                  let eaten = intakeByDay[day], eaten > 0 else { continue }
            balance += Double(dailyTarget) - eaten
        }
        return Int(balance.rounded())
    }

    static func isOnBreak(start: Date?, end: Date?, on date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let start, let end else { return false }
        let day = calendar.startOfDay(for: date)
        return day >= calendar.startOfDay(for: start) && day < calendar.startOfDay(for: end)
    }

    /// The goal date moved later by the break days still ahead, since weight is held during a break.
    static func goalDate(_ projected: Date?, breakStart: Date?, breakEnd: Date?, today: Date = .now,
                         calendar: Calendar = .current) -> Date? {
        guard let projected, let breakStart, let breakEnd else { return projected }
        let from = max(calendar.startOfDay(for: today), calendar.startOfDay(for: breakStart))
        let to = calendar.startOfDay(for: breakEnd)
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        return days > 0 ? calendar.date(byAdding: .day, value: days, to: projected) : projected
    }
}
