import Foundation

/// A plain-text progress update for a friend, partner or coach, sent through the share sheet.
/// The person chooses which sections go in; individual foods and photos are never included,
/// and daily calories are totals only, off until switched on.
enum PartnerSummary {
    static let weightTrendKey = "partnerShareWeightTrend"
    static let weekKey = "partnerShareWeek"
    static let streaksKey = "partnerShareStreaks"
    static let dailyCaloriesKey = "partnerShareDailyCalories"

    struct Options: Equatable {
        var weightTrend = true
        var week = true
        var streaks = true
        var dailyCalories = false

        var isEmpty: Bool { !(weightTrend || week || streaks || dailyCalories) }
    }

    struct Input {
        var weights: [WeeklyReviewCalculator.WeightDay]
        var review: WeeklyReview
        var loggingStreak: Int
        var proteinStreak: Int
        /// Calories per day, keyed by start of day.
        var caloriesByDay: [Date: Double]
        var units: Units
        var today: Date = .now
        var calendar: Calendar = .current
    }

    /// The whole message, or an empty string when nothing is chosen.
    static func text(_ input: Input, options: Options) -> String {
        guard !options.isEmpty else { return "" }
        let date = input.today.formatted(.dateTime.month(.abbreviated).day())
        var sections = [String(localized: "My progress update (\(date))")]
        if options.weightTrend { sections.append(lines(String(localized: "Weight"), weightTrendLines(input))) }
        if options.week { sections.append(lines(String(localized: "Last 7 days"), weekLines(input.review, units: input.units))) }
        if options.streaks { sections.append(lines(String(localized: "Streaks"), streakLines(logging: input.loggingStreak, protein: input.proteinStreak))) }
        if options.dailyCalories { sections.append(lines(String(localized: "Daily calories"), dailyCalorieLines(input))) }
        sections.append(String(localized: "Sent from Stride"))
        return sections.joined(separator: "\n\n")
    }

    private static func lines(_ title: String, _ body: [String]) -> String {
        ([title] + body.map { "• \($0)" }).joined(separator: "\n")
    }

    /// Change since the first weigh-in and over the last four weeks, with the weekly rate.
    static func weightTrendLines(_ input: Input) -> [String] {
        let sorted = input.weights.sorted { $0.date < $1.date }
        guard let first = sorted.first, let latest = sorted.last, latest.date > first.date else {
            return [String(localized: "Not enough weigh-ins yet")]
        }
        let units = input.units
        let since = first.date.formatted(.dateTime.month(.abbreviated).day())
        var result = [String(localized: "\(units.weightString(kg: latest.weightKg - first.weightKg, signed: true)) since \(since)")]
        let cutoff = input.calendar.date(byAdding: .day, value: -28, to: input.calendar.startOfDay(for: latest.date)) ?? latest.date
        if let base = sorted.last(where: { $0.date <= cutoff }) {
            let change = latest.weightKg - base.weightKg
            let weeks = max(latest.date.timeIntervalSince(base.date) / (7 * 86_400), 1)
            result.append(String(localized: "\(units.weightString(kg: change, signed: true)) over the last 4 weeks (\(units.weightString(kg: change / weeks, signed: true)) a week)"))
        }
        return result
    }

    static func weekLines(_ review: WeeklyReview, units: Units) -> [String] {
        var result = [String(localized: "Logged food on \(review.daysLogged) of 7 days")]
        if let average = review.averageIntake {
            result.append(String(localized: "Average \(Energy.string(average)) a day, target \(Energy.string(review.budget))"))
        }
        if let change = review.weightChangeKg {
            result.append(String(localized: "Weight \(units.weightString(kg: change, signed: true)) on the week before"))
        }
        if review.completedFasts > 0 {
            result.append(String(localized: "\(review.completedFasts) fasts completed"))
        }
        if review.hasContent { result.append(review.headline) }
        return result
    }

    static func streakLines(logging: Int, protein: Int) -> [String] {
        var result = [String(localized: "Logged \(logging) days in a row")]
        if protein >= 2 { result.append(String(localized: "Hit the protein goal \(protein) days in a row")) }
        return result
    }

    /// The seven days before today, oldest first, matching the weekly review's window.
    static func dailyCalorieLines(_ input: Input) -> [String] {
        let calendar = input.calendar
        let today = calendar.startOfDay(for: input.today)
        return (1...7).reversed().compactMap { offset -> String? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let label = day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            guard let kcal = input.caloriesByDay[day], kcal > 0 else { return String(localized: "\(label): not logged") }
            return "\(label): \(Energy.string(kcal))"
        }
    }
}
