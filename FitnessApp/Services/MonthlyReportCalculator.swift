import Foundation

/// One calendar month at a glance: how the trend weight moved, the best week, how consistently
/// food was logged, and fasts and workouts. The current month runs up to today.
struct MonthlyReport: Equatable {
    struct BestWeek: Equatable {
        var start: Date
        /// Negative is a loss.
        var changeKg: Double
    }

    var month: DateInterval
    /// Days of the month so far (the whole month once it's over).
    var daysSoFar: Int
    var isComplete: Bool
    /// Seven-day trend at the start and end of the month.
    var startTrendKg: Double?
    var endTrendKg: Double?
    var bestWeek: BestWeek?
    var daysLogged: Int
    var longestStreak: Int
    /// Mean calories on logged days.
    var averageIntake: Double?
    var budget: Int
    var completedFasts: Int
    var workouts: Int

    /// Negative is a loss; nil without a trend at both ends.
    var changeKg: Double? {
        guard let startTrendKg, let endTrendKg else { return nil }
        return endTrendKg - startTrendKg
    }

    var hasContent: Bool { daysLogged > 0 || changeKg != nil || completedFasts > 0 || workouts > 0 }
}

enum MonthlyReportCalculator {
    typealias FoodDay = WeeklyReviewCalculator.FoodDay
    typealias WeightDay = WeeklyReviewCalculator.WeightDay

    static func report(month containing: Date,
                       foodLogs: [FoodDay],
                       weights: [WeightDay],
                       budget: Int,
                       fasts: [FastingCalculator.Fast] = [],
                       workoutDates: [Date] = [],
                       today: Date = .now,
                       calendar: Calendar = .current) -> MonthlyReport? {
        guard let month = calendar.dateInterval(of: .month, for: containing) else { return nil }
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)) ?? today
        let end = min(month.end, todayEnd)
        guard end > month.start else { return nil }
        let isComplete = month.end <= todayEnd
        let lastDay = calendar.date(byAdding: .day, value: -1, to: end) ?? month.start
        let daysSoFar = (calendar.dateComponents([.day], from: month.start, to: end).day ?? 0)

        // Seven-day trends smooth out day-to-day water swings at either end.
        let startTrend = ProgressCalculator.trend(on: month.start, weights: weights, calendar: calendar)
        let endTrend = ProgressCalculator.trend(on: lastDay, weights: weights, calendar: calendar)

        // Logging
        var intake: [Date: Double] = [:]
        for log in foodLogs where log.date >= month.start && log.date < end {
            intake[calendar.startOfDay(for: log.date), default: 0] += log.calories
        }
        var longest = 0, run = 0
        var day = month.start
        while day < end {
            run = intake[day] != nil ? run + 1 : 0
            longest = max(longest, run)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? end
        }

        return MonthlyReport(
            month: month,
            daysSoFar: daysSoFar,
            isComplete: isComplete,
            startTrendKg: startTrend,
            endTrendKg: endTrend,
            bestWeek: bestWeek(from: month.start, to: end, weights: weights, calendar: calendar),
            daysLogged: intake.count,
            longestStreak: longest,
            averageIntake: intake.isEmpty ? nil : intake.values.reduce(0, +) / Double(intake.count),
            budget: budget,
            completedFasts: FastingCalculator.completed(fasts, from: month.start, to: end),
            workouts: workoutDates.filter { $0 >= month.start && $0 < end }.count)
    }

    /// The seven-day stretch (starting on any day of the month) that lost the most: the last
    /// weigh-in of the week against the last one in the three days before it (or the week's
    /// first). Only full weeks inside the range count; nil if none lost weight.
    static func bestWeek(from start: Date, to end: Date, weights: [WeightDay],
                         calendar: Calendar = .current) -> MonthlyReport.BestWeek? {
        let sorted = weights.sorted { $0.date < $1.date }
        var best: MonthlyReport.BestWeek?
        var weekStart = start
        while let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart), weekEnd <= end {
            let lead = calendar.date(byAdding: .day, value: -3, to: weekStart) ?? weekStart
            let inWeek = sorted.filter { $0.date >= weekStart && $0.date < weekEnd }
            let before = sorted.last { $0.date >= lead && $0.date < weekStart }
            if let last = inWeek.last, let first = before ?? inWeek.first, first.date < last.date {
                let change = last.weightKg - first.weightKg
                if change < 0, change < (best?.changeKg ?? 0) {
                    best = .init(start: weekStart, changeKg: change)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: weekStart) else { break }
            weekStart = next
        }
        return best
    }
}
