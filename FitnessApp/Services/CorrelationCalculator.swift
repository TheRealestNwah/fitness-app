import Foundation

/// Pairs two daily measures so they can be charted against each other, and summarises
/// the pairing in plain terms rather than statistics.
enum CorrelationCalculator {
    struct Pair: Equatable {
        var date: Date
        var x: Double
        var y: Double
    }

    /// How the y-values differ between the lower and higher halves of the x-values.
    struct Split: Equatable {
        var medianX: Double
        var lowMeanY: Double
        var highMeanY: Double
        var difference: Double { highMeanY - lowMeanY }
    }

    static let minimumForChart = 3
    static let minimumForSummary = 6

    static func dailyTotals(_ values: [(date: Date, value: Double)], calendar: Calendar = .current) -> [Date: Double] {
        var totals: [Date: Double] = [:]
        for item in values { totals[calendar.startOfDay(for: item.date), default: 0] += item.value }
        return totals
    }

    /// Sleep logged on a day (the night before it) against the calories eaten that day.
    static func sleepVersusIntake(sleep: [(date: Date, hours: Double)],
                                  food: [(date: Date, calories: Double)],
                                  calendar: Calendar = .current) -> [Pair] {
        let intake = dailyTotals(food.map { (date: $0.date, value: $0.calories) }, calendar: calendar)
        return sleep.compactMap { reading -> Pair? in
            let day = calendar.startOfDay(for: reading.date)
            guard let kcal = intake[day], kcal > 0 else { return nil }
            return Pair(date: day, x: reading.hours, y: kcal)
        }
        .sorted { $0.date < $1.date }
    }

    /// Sodium eaten the day before a blood-pressure reading against its systolic value.
    /// Days with no sodium recorded are left out rather than counted as zero.
    static func sodiumVersusSystolic(readings: [(date: Date, systolic: Double)],
                                     food: [(date: Date, sodiumMg: Double)],
                                     calendar: Calendar = .current) -> [Pair] {
        let sodium = dailyTotals(food.map { (date: $0.date, value: $0.sodiumMg) }, calendar: calendar)
        return readings.compactMap { reading -> Pair? in
            let day = calendar.startOfDay(for: reading.date)
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day),
                  let mg = sodium[previous], mg > 0 else { return nil }
            return Pair(date: day, x: mg, y: reading.systolic)
        }
        .sorted { $0.date < $1.date }
    }

    /// A day's food total (protein or calories) against the average hunger rated before that
    /// day's meals. Days without a hunger rating or without food are left out.
    static func hungerVersus(_ food: [(date: Date, value: Double)], hunger: [(date: Date, rating: Int)],
                             calendar: Calendar = .current) -> [Pair] {
        let totals = dailyTotals(food, calendar: calendar)
        var ratings: [Date: [Int]] = [:]
        for item in hunger { ratings[calendar.startOfDay(for: item.date), default: []].append(item.rating) }
        return ratings.compactMap { day, values -> Pair? in
            guard let total = totals[day], total > 0, !values.isEmpty else { return nil }
            return Pair(date: day, x: total, y: Double(values.reduce(0, +)) / Double(values.count))
        }
        .sorted { $0.date < $1.date }
    }

    /// Splits at the median x and compares the average y on each side.
    static func split(_ pairs: [Pair]) -> Split? {
        guard pairs.count >= minimumForSummary else { return nil }
        let xs = pairs.map(\.x).sorted()
        let median = xs.count % 2 == 0 ? (xs[xs.count / 2 - 1] + xs[xs.count / 2]) / 2 : xs[xs.count / 2]
        let low = pairs.filter { $0.x <= median }.map(\.y)
        let high = pairs.filter { $0.x > median }.map(\.y)
        guard !low.isEmpty, !high.isEmpty else { return nil }
        return Split(medianX: median,
                     lowMeanY: low.reduce(0, +) / Double(low.count),
                     highMeanY: high.reduce(0, +) / Double(high.count))
    }
}
