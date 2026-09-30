import Foundation

/// A spoken summary of a line chart for VoiceOver: how many readings, over what dates,
/// where it started and ended, and the range. Swift Charts reads individual points; this
/// gives the gist first.
enum ChartSummary {
    static func describe(_ points: [(date: Date, value: Double)], format: (Double) -> String) -> String {
        let sorted = points.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return String(localized: "No readings") }
        func day(_ date: Date) -> String { date.formatted(date: .abbreviated, time: .omitted) }
        guard sorted.count > 1 else { return String(localized: "One reading, \(format(first.value)) on \(day(first.date)).") }

        let change = last.value - first.value
        let direction: String
        if abs(change) < 0.05 {
            direction = String(localized: "no change")
        } else if change < 0 {
            direction = String(localized: "down \(format(-change))")
        } else {
            direction = String(localized: "up \(format(change))")
        }
        let values = sorted.map(\.value)
        let low = values.min() ?? first.value
        let high = values.max() ?? first.value
        return String(localized: "\(sorted.count) readings from \(day(first.date)) to \(day(last.date)). Started at \(format(first.value)), latest \(format(last.value)), \(direction). Lowest \(format(low)), highest \(format(high)).")
    }
}
