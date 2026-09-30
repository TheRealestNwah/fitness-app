import Foundation

/// Every 5% of starting weight lost, measured on the 7-day trend so a single light morning doesn't count.
struct Milestone: Equatable {
    var percent: Int
    var thresholdKg: Double
    /// First day the trend reached the threshold.
    var reachedOn: Date
}

/// When the goal will be reached if weight keeps falling at the rate it actually has been.
struct TrendForecast: Equatable {
    /// Recent loss per week, from a straight-line fit through the weigh-ins. Positive means losing.
    var weeklyLossKg: Double
    var goalDate: Date
}

/// The trend has stalled while there is still weight to lose.
struct Plateau: Equatable {
    /// How long the trend has stayed within `ProgressCalculator.plateauToleranceKg`.
    var days: Int
    var trendKg: Double
    var suggestions: [String]
}

enum ProgressCalculator {
    static let milestoneStepPercent = 5
    static let trendWindowDays = 7
    static let plateauMinimumDays = 14
    /// Movement smaller than this over the plateau window counts as "hasn't moved".
    static let plateauToleranceKg = 0.3
    static let plateauMinimumWeighIns = 4
    static let forecastWindowDays = 28
    static let forecastMinimumSpanDays = 14
    static let forecastMinimumWeighIns = 5
    /// Slower than this and the goal is too far off to put a date on.
    static let forecastMinimumWeeklyLossKg = 0.05
    static let forecastMaximumDays = 3 * 365

    typealias WeightDay = WeeklyReviewCalculator.WeightDay

    /// Mean of the weigh-ins in the `trendWindowDays` ending on `day` (inclusive), or nil if there are none.
    static func trend(on day: Date, weights: [WeightDay], calendar: Calendar = .current) -> Double? {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) ?? day
        let start = calendar.date(byAdding: .day, value: -trendWindowDays, to: end) ?? end
        let window = weights.filter { $0.date >= start && $0.date < end }.map(\.weightKg)
        return window.isEmpty ? nil : window.reduce(0, +) / Double(window.count)
    }

    /// Every milestone reached so far, oldest first.
    static func milestones(startKg: Double, weights: [WeightDay], calendar: Calendar = .current) -> [Milestone] {
        guard startKg > 0 else { return [] }
        let days = Set(weights.map { calendar.startOfDay(for: $0.date) }).sorted()
        var reached: [Milestone] = []
        var next = milestoneStepPercent
        for day in days {
            guard let trend = trend(on: day, weights: weights, calendar: calendar) else { continue }
            while trend <= startKg * (1 - Double(next) / 100) {
                reached.append(Milestone(percent: next, thresholdKg: startKg * (1 - Double(next) / 100), reachedOn: day))
                next += milestoneStepPercent
            }
        }
        return reached
    }

    /// The next milestone and how far away it is on the current trend.
    static func nextMilestone(startKg: Double, weights: [WeightDay], today: Date = .now,
                              calendar: Calendar = .current) -> (percent: Int, remainingKg: Double)? {
        guard startKg > 0,
              let current = trend(on: today, weights: weights, calendar: calendar)
                ?? weights.max(by: { $0.date < $1.date })?.weightKg else { return nil }
        let reached = milestones(startKg: startKg, weights: weights, calendar: calendar).last?.percent ?? 0
        let percent = reached + milestoneStepPercent
        let threshold = startKg * (1 - Double(percent) / 100)
        return (percent, max(current - threshold, 0))
    }

    /// A milestone reached in the last `withinDays` days, for a celebration card.
    static func recentMilestone(startKg: Double, weights: [WeightDay], today: Date = .now,
                                withinDays: Int = 7, calendar: Calendar = .current) -> Milestone? {
        guard let latest = milestones(startKg: startKg, weights: weights, calendar: calendar).last,
              let days = calendar.dateComponents([.day], from: latest.reachedOn,
                                                 to: calendar.startOfDay(for: today)).day,
              days < withinDays else { return nil }
        return latest
    }

    /// Detects a stall: the 7-day trend has moved less than `plateauToleranceKg` for at least
    /// `plateauMinimumDays`, with regular weigh-ins, while the goal is still ahead.
    static func plateau(weights: [WeightDay],
                        goalKg: Double,
                        currentTarget: Int,
                        maintenance: MaintenanceEstimate?,
                        weeklyLossKg: Double,
                        sex: BiologicalSex,
                        today: Date = .now,
                        calendar: Calendar = .current) -> Plateau? {
        let todayStart = calendar.startOfDay(for: today)
        guard let now = trend(on: todayStart, weights: weights, calendar: calendar), now > goalKg else { return nil }

        // Walk back day by day while the trend stays within tolerance of today's.
        var days = 0
        var cursor = todayStart
        while let previous = calendar.date(byAdding: .day, value: -1, to: cursor),
              let value = trend(on: previous, weights: weights, calendar: calendar),
              abs(value - now) < plateauToleranceKg {
            days += 1
            cursor = previous
            if days > 365 { break }
        }
        guard days >= plateauMinimumDays else { return nil }
        let windowStart = calendar.date(byAdding: .day, value: -days, to: todayStart) ?? todayStart
        let weighIns = weights.filter { $0.date >= windowStart }.count
        guard weighIns >= plateauMinimumWeighIns else { return nil }

        var suggestions: [String] = []
        if let maintenance {
            let suggested = maintenance.suggestedTarget(weeklyLossKg: weeklyLossKg, sex: sex)
            if suggested < currentTarget {
                suggestions.append(String(localized: "Your measured maintenance is about \(Energy.string(maintenance.maintenanceKcal)). A target of \(Energy.string(suggested)) matches your planned rate; you can apply it in Settings."))
            } else {
                suggestions.append(String(localized: "Your target already sits below your measured maintenance of about \(Energy.string(maintenance.maintenanceKcal)), so the gap is more likely in logging than in the plan."))
            }
        } else {
            suggestions.append(String(localized: "Log food on most days for two more weeks so the adaptive target can measure your real maintenance."))
        }
        suggestions.append(String(localized: "Weigh portions for a week. Oils, sauces and drinks are the usual under-counts."))
        suggestions.append(String(localized: "Water retention from stress, sleep or new training can hide fat loss for a week or two."))
        suggestions.append(String(localized: "If you've been dieting for months, a 1–2 week break at maintenance can make the next stretch easier."))
        return Plateau(days: days, trendKg: now, suggestions: suggestions)
    }

    /// Fits a line through the last `forecastWindowDays` of weigh-ins and projects when the 7-day trend
    /// reaches `goalKg` at that rate. Nil without enough data (at least `forecastMinimumWeighIns` spread
    /// over `forecastMinimumSpanDays`), when weight is flat or rising, when the goal is already reached,
    /// or when the date would be more than `forecastMaximumDays` away.
    static func trendForecast(weights: [WeightDay], goalKg: Double, today: Date = .now,
                              calendar: Calendar = .current) -> TrendForecast? {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)) ?? today
        let start = calendar.date(byAdding: .day, value: -forecastWindowDays, to: end) ?? end
        let window = weights.filter { $0.date >= start && $0.date < end }
        guard window.count >= forecastMinimumWeighIns,
              let first = window.map(\.date).min(), let last = window.map(\.date).max(),
              last.timeIntervalSince(first) >= Double(forecastMinimumSpanDays - 1) * 86_400 else { return nil }

        let points = window.map { (x: $0.date.timeIntervalSince(first) / 86_400, y: $0.weightKg) }
        let n = Double(points.count)
        let meanX = points.reduce(0) { $0 + $1.x } / n
        let meanY = points.reduce(0) { $0 + $1.y } / n
        let sxx = points.reduce(0) { $0 + ($1.x - meanX) * ($1.x - meanX) }
        guard sxx > 0 else { return nil }
        let slopePerDay = points.reduce(0) { $0 + ($1.x - meanX) * ($1.y - meanY) } / sxx
        let weeklyLoss = -slopePerDay * 7
        guard weeklyLoss >= forecastMinimumWeeklyLossKg,
              let current = trend(on: today, weights: weights, calendar: calendar),
              current > goalKg else { return nil }

        let days = ((current - goalKg) / -slopePerDay).rounded()
        guard days <= Double(forecastMaximumDays),
              let date = calendar.date(byAdding: .day, value: Int(days), to: calendar.startOfDay(for: today)) else { return nil }
        return TrendForecast(weeklyLossKg: weeklyLoss, goalDate: date)
    }
}
