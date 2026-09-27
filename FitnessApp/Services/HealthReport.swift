import Foundation

/// What goes in the doctor-friendly report: weight and vitals over a period, oldest first.
struct HealthReport: Equatable {
    struct WeightPoint: Equatable { var date: Date; var kg: Double }
    struct Reading: Equatable {
        var date: Date
        var systolic: Int?
        var diastolic: Int?
        var heartRate: Int?
        var glucose: Double?
        var waistCm: Double?
    }

    var start: Date
    var end: Date
    var weights: [WeightPoint]
    var readings: [Reading]

    var weightChangeKg: Double? {
        guard let first = weights.first, let last = weights.last, weights.count >= 2 else { return nil }
        return last.kg - first.kg
    }

    var averageBloodPressure: (systolic: Int, diastolic: Int)? {
        var systolic: [Double] = [], diastolic: [Double] = []
        for r in readings {
            if let s = r.systolic, let d = r.diastolic {
                systolic.append(Double(s))
                diastolic.append(Double(d))
            }
        }
        guard let s = Self.average(systolic), let d = Self.average(diastolic) else { return nil }
        return (Int(s.rounded()), Int(d.rounded()))
    }

    var averageHeartRate: Int? { Self.average(readings.compactMap(\.heartRate).map(Double.init)).map { Int($0.rounded()) } }
    var averageGlucose: Double? { Self.average(readings.compactMap(\.glucose)) }

    private static func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    static let defaultDays = 90

    /// The last `days` days ending today; readings with none of the reported vitals are left out.
    static func make(weights: [(date: Date, kg: Double)],
                     vitals: [Reading],
                     days: Int = defaultDays,
                     today: Date = .now,
                     calendar: Calendar = .current) -> HealthReport {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)) ?? today
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? end
        let inRange = { (date: Date) in date >= start && date < end }
        return HealthReport(
            start: start,
            end: end,
            weights: weights.filter { inRange($0.date) }.sorted { $0.date < $1.date }.map { WeightPoint(date: $0.date, kg: $0.kg) },
            readings: vitals.filter { r in
                inRange(r.date) && (r.systolic != nil || r.heartRate != nil || r.glucose != nil || r.waistCm != nil)
            }.sorted { $0.date < $1.date })
    }
}
