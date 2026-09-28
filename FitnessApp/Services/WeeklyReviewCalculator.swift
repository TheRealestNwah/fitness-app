import Foundation

/// Summary of the seven complete days ending yesterday.
struct WeeklyReview: Equatable {
    /// Days in the window with at least one diary entry (0...7).
    var daysLogged: Int
    /// Mean calories on logged days; nil when nothing was logged.
    var averageIntake: Double?
    var budget: Int
    /// Mean weight over the window minus the mean over the seven days before it; nil without data on both sides.
    var weightChangeKg: Double?
    var plannedWeeklyLossKg: Double
    var headline: String
    var suggestion: String
    /// Fasts that reached their target in the window.
    var completedFasts: Int = 0

    var hasContent: Bool { daysLogged > 0 || weightChangeKg != nil || completedFasts > 0 }

    /// Positive when intake exceeded the budget.
    var overBudget: Double? {
        averageIntake.map { $0 - Double(budget) }
    }
}

enum WeeklyReviewCalculator {
    struct FoodDay { var date: Date; var calories: Double }
    struct WeightDay { var date: Date; var weightKg: Double }

    static func review(foodLogs: [FoodDay],
                       weights: [WeightDay],
                       budget: Int,
                       plannedWeeklyLossKg: Double,
                       fasts: [FastingCalculator.Fast] = [],
                       today: Date = .now,
                       calendar: Calendar = .current) -> WeeklyReview {
        let todayStart = calendar.startOfDay(for: today)
        let windowEnd = todayStart                                  // exclusive: yesterday is the last day
        let windowStart = calendar.date(byAdding: .day, value: -7, to: windowEnd) ?? windowEnd
        let priorStart = calendar.date(byAdding: .day, value: -7, to: windowStart) ?? windowStart

        // Intake
        var perDay: [Date: Double] = [:]
        for log in foodLogs where log.date >= windowStart && log.date < windowEnd {
            perDay[calendar.startOfDay(for: log.date), default: 0] += log.calories
        }
        let daysLogged = perDay.count
        let averageIntake: Double? = daysLogged > 0 ? perDay.values.reduce(0, +) / Double(daysLogged) : nil

        // Weight
        let current = weights.filter { $0.date >= windowStart && $0.date < windowEnd }.map(\.weightKg)
        let prior = weights.filter { $0.date >= priorStart && $0.date < windowStart }.map(\.weightKg)
        let weightChange: Double?
        if !current.isEmpty, !prior.isEmpty {
            weightChange = current.reduce(0, +) / Double(current.count) - prior.reduce(0, +) / Double(prior.count)
        } else {
            weightChange = nil
        }

        let (headline, suggestion) = advice(daysLogged: daysLogged,
                                            averageIntake: averageIntake,
                                            budget: budget,
                                            weightChange: weightChange,
                                            planned: plannedWeeklyLossKg)

        return WeeklyReview(daysLogged: daysLogged,
                            averageIntake: averageIntake,
                            budget: budget,
                            weightChangeKg: weightChange,
                            plannedWeeklyLossKg: plannedWeeklyLossKg,
                            headline: headline,
                            suggestion: suggestion,
                            completedFasts: FastingCalculator.completed(fasts, from: windowStart, to: windowEnd))
    }

    /// One headline and one concrete next step, chosen by simple rules in priority order.
    static func advice(daysLogged: Int,
                       averageIntake: Double?,
                       budget: Int,
                       weightChange: Double?,
                       planned: Double) -> (headline: String, suggestion: String) {
        guard daysLogged > 0, let avg = averageIntake else {
            if let change = weightChange {
                let amount = String(format: "%.1f", abs(change))
                return (change <= 0 ? String(localized: "Weight down \(amount) kg, no meals logged") : String(localized: "Weight up \(amount) kg, no meals logged"),
                        String(localized: "Log at least one meal a day. Even rough entries show which days push you over."))
            }
            return (String(localized: "Nothing logged in the last 7 days"),
                    String(localized: "Start with one meal a day. Favourite meals and copy-yesterday make it a two-tap habit."))
        }

        if daysLogged < 4 {
            return (String(localized: "Only \(daysLogged) of 7 days logged"),
                    String(localized: "Consistency beats precision. Aim for 5 logged days next week, using favourite meals for the usual ones."))
        }

        let over = avg - Double(budget)
        if avg < Double(budget) * 0.6 {
            return (String(localized: "Logged intake looks incomplete"),
                    String(localized: "Averaging \(Int(avg.rounded())) kcal a day is well under any safe budget, so meals are probably missing. Log everything, including drinks, so the review means something."))
        }
        if over > Double(budget) * 0.10 {
            return (String(localized: "Averaging \(Int(over.rounded())) kcal over budget"),
                    String(localized: "Check drinks, sauces and evening snacks first. Trimming about 200 kcal a day gets you back on plan."))
        }

        guard let change = weightChange else {
            return (String(localized: "Intake on budget"),
                    String(localized: "Weigh in a few mornings a week so next week's review can compare the scale with your intake."))
        }

        if planned > 0, change <= -(planned * 1.5) {
            let amount = String(format: "%.1f", abs(change))
            return (String(localized: "Losing faster than planned (\(amount) kg)"),
                    String(localized: "Faster is not always better. Keep protein high and do not skip meals; a slightly higher target is fine."))
        }
        if change > 0.3 {
            let amount = String(format: "%.1f", change)
            return (String(localized: "Weight up \(amount) kg with intake on budget"),
                    String(localized: "Water and salt swing the scale by a kilo or two. Judge by the trend line and give it another week."))
        }
        if change <= -(planned * 0.5) {
            let amount = String(format: "%.1f", abs(change))
            return (String(localized: "On track: down \(amount) kg this week"),
                    String(localized: "Keep doing what you are doing. Plan next week's dinners now while motivation is high."))
        }
        return (String(localized: "Intake on budget, scale moving slowly"),
                String(localized: "Normal in weeks two to four. If it stays flat next week, trim 100 to 150 kcal or add a daily walk."))
    }
}
