import Foundation

/// How close the data is to supporting a trend-based insight, so early screens can say
/// "3 of 5 weigh-ins" instead of showing nothing.
struct TrendProgress: Equatable {
    var weighIns: Int
    var weighInsNeeded: Int
    /// Days from the first to the last weigh-in in the window, counting both.
    var spanDays: Int
    var spanDaysNeeded: Int
    var daysLogged: Int = 0
    var daysLoggedNeeded: Int = 0

    var isReady: Bool {
        weighIns >= weighInsNeeded && spanDays >= spanDaysNeeded && daysLogged >= daysLoggedNeeded
    }

    var needsWeighIns: Bool { weighIns < weighInsNeeded || spanDays < spanDaysNeeded }

    /// 0…1, the average progress across the requirements.
    var fraction: Double {
        var parts = [ratio(weighIns, weighInsNeeded), ratio(spanDays, spanDaysNeeded)]
        if daysLoggedNeeded > 0 { parts.append(ratio(daysLogged, daysLoggedNeeded)) }
        return parts.reduce(0, +) / Double(parts.count)
    }

    /// What's still missing, e.g. ["3 of 5 weigh-ins", "spread over 6 of 14 days"].
    var missing: [String] {
        var parts: [String] = []
        if weighIns < weighInsNeeded {
            parts.append(String(localized: "\(weighIns) of \(weighInsNeeded) weigh-ins"))
        }
        if spanDays < spanDaysNeeded {
            parts.append(String(localized: "spread over \(spanDays) of \(spanDaysNeeded) days"))
        }
        if daysLogged < daysLoggedNeeded {
            parts.append(String(localized: "\(daysLogged) of \(daysLoggedNeeded) days of food logged"))
        }
        return parts
    }

    var summary: String {
        let text = missing.joined(separator: ", ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private func ratio(_ have: Int, _ need: Int) -> Double {
        need > 0 ? min(Double(have) / Double(need), 1) : 1
    }
}

/// The data each trend insight needs. Thresholds come from the calculators that use them.
enum TrendReadiness {
    /// The weekly rate on the Weight screen.
    static let rateWindowDays = 28
    static let rateMinimumWeighIns = 3
    static let rateMinimumSpanDays = 7

    static func rate(weights: [WeeklyReviewCalculator.WeightDay], today: Date = .now,
                     calendar: Calendar = .current) -> TrendProgress {
        let window = recent(weights, days: rateWindowDays, today: today, calendar: calendar)
        return TrendProgress(weighIns: window.count, weighInsNeeded: rateMinimumWeighIns,
                             spanDays: span(window), spanDaysNeeded: rateMinimumSpanDays)
    }

    /// The goal-date forecast from the weight trend (`ProgressCalculator.trendForecast`).
    static func forecast(weights: [WeeklyReviewCalculator.WeightDay], today: Date = .now,
                         calendar: Calendar = .current) -> TrendProgress {
        let window = recent(weights, days: ProgressCalculator.forecastWindowDays, today: today, calendar: calendar)
        return TrendProgress(weighIns: window.count, weighInsNeeded: ProgressCalculator.forecastMinimumWeighIns,
                             spanDays: span(window), spanDaysNeeded: ProgressCalculator.forecastMinimumSpanDays)
    }

    /// The measured maintenance estimate (`AdaptiveTargetCalculator.estimate`), which looks at the
    /// days before today only.
    static func maintenance(foodLogs: [WeeklyReviewCalculator.FoodDay], weights: [WeeklyReviewCalculator.WeightDay],
                            today: Date = .now, calendar: Calendar = .current) -> TrendProgress {
        let end = calendar.startOfDay(for: today)
        let start = calendar.date(byAdding: .day, value: -AdaptiveTargetCalculator.windowDays, to: end) ?? end
        let window = weights.filter { $0.date >= start && $0.date < end }
        let days = Set(foodLogs.filter { $0.date >= start && $0.date < end }.map { calendar.startOfDay(for: $0.date) })
        return TrendProgress(weighIns: window.count, weighInsNeeded: AdaptiveTargetCalculator.minimumWeighIns,
                             spanDays: span(window), spanDaysNeeded: AdaptiveTargetCalculator.minimumWeighInSpanDays,
                             daysLogged: days.count, daysLoggedNeeded: AdaptiveTargetCalculator.minimumDaysLogged)
    }

    /// Weigh-ins from the last `days` days up to the end of today.
    private static func recent(_ weights: [WeeklyReviewCalculator.WeightDay], days: Int, today: Date,
                               calendar: Calendar) -> [WeeklyReviewCalculator.WeightDay] {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)) ?? today
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? end
        return weights.filter { $0.date >= start && $0.date < end }
    }

    private static func span(_ window: [WeeklyReviewCalculator.WeightDay]) -> Int {
        guard let first = window.map(\.date).min(), let last = window.map(\.date).max() else { return 0 }
        return Int(last.timeIntervalSince(first) / 86_400) + 1
    }
}
