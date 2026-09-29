import Foundation

/// Marks the days around a period when water retention commonly lifts the scale, from the
/// menstrual flow days in Apple Health, so a cycle bump isn't read as a stall.
enum CycleCalculator {
    static let enabledKey = "cycleAwareWeight"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// Retention usually starts a few days before a period and eases in its first days.
    static let daysBefore = 5
    static let daysAfter = 2
    static let typicalCycleDays = 28

    /// First days of each period: a flow day with no flow on the two days before it.
    static func periodStarts(flowDays: [Date], calendar: Calendar = .current) -> [Date] {
        let days = Set(flowDays.map { calendar.startOfDay(for: $0) })
        return days.filter { day in
            (1...2).allSatisfy { offset in
                calendar.date(byAdding: .day, value: -offset, to: day).map { !days.contains($0) } ?? true
            }
        }
        .sorted()
    }

    /// Average gap between recent period starts, if the gaps look like cycles (21–40 days).
    static func averageCycleDays(_ starts: [Date], calendar: Calendar = .current) -> Int? {
        let gaps = zip(starts, starts.dropFirst()).compactMap { calendar.dateComponents([.day], from: $0, to: $1).day }
            .filter { (21...40).contains($0) }
        guard !gaps.isEmpty else { return nil }
        return Int((Double(gaps.reduce(0, +)) / Double(gaps.count)).rounded())
    }

    /// Likely retention days up to `today`: around each recorded period, and around the next
    /// expected one once it's close.
    static func retentionDays(periodStarts starts: [Date], today: Date = .now,
                              calendar: Calendar = .current) -> Set<Date> {
        let todayStart = calendar.startOfDay(for: today)
        var windows = starts
        if let last = starts.last,
           let next = calendar.date(byAdding: .day, value: averageCycleDays(starts, calendar: calendar) ?? typicalCycleDays, to: last),
           next > todayStart {
            windows.append(next)
        }
        var days = Set<Date>()
        for start in windows {
            for offset in -daysBefore...daysAfter {
                if let day = calendar.date(byAdding: .day, value: offset, to: start), day <= todayStart {
                    days.insert(day)
                }
            }
        }
        return days
    }

    /// Weigh-ins with retention days left out, for trend-based checks like plateau detection.
    /// Keeps everything if leaving them out would leave too little to work with.
    static func excludingRetention(_ weights: [WeeklyReviewCalculator.WeightDay], days: Set<Date>,
                                   calendar: Calendar = .current) -> [WeeklyReviewCalculator.WeightDay] {
        guard !days.isEmpty else { return weights }
        let kept = weights.filter { !days.contains(calendar.startOfDay(for: $0.date)) }
        return kept.count * 2 >= weights.count ? kept : weights
    }
}
