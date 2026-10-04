import SwiftUI
import SwiftData
import Charts

/// Waist, hips and chest on one chart, and body fat alongside the weight trend.
struct BodyTrendsView: View {
    @Environment(UserProfile.self) private var profile
    @Query(sort: \VitalsEntry.date) private var vitals: [VitalsEntry]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]

    private var units: Units { profile.units }

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let series: String
        let value: Double
    }

    private var measurements: [Point] {
        vitals.flatMap { e -> [Point] in
            [("Waist", e.waistCm), ("Hips", e.hipCm), ("Chest", e.chestCm)].compactMap { name, cm in
                cm.map { Point(date: e.date, series: name, value: units.lengthValue(cm: $0)) }
            }
        }
    }

    private var bodyFat: [Point] {
        vitals.compactMap { e in e.bodyFatPercent.map { Point(date: e.date, series: "Body fat", value: $0) } }
    }

    /// The 7-day weight trend on each weigh-in day.
    private var weightTrend: [Point] {
        let days = weights.map { WeeklyReviewCalculator.WeightDay(date: $0.date, weightKg: $0.weightKg) }
        let unique = Set(days.map { Calendar.current.startOfDay(for: $0.date) }).sorted()
        return unique.compactMap { day in
            ProgressCalculator.trend(on: day, weights: days)
                .map { Point(date: day, series: "Weight trend", value: units.weightValue(kg: $0)) }
        }
    }

    /// Both charts share the body-fat readings' date range so they line up.
    private var fatDomain: ClosedRange<Date>? {
        guard let first = bodyFat.first?.date, let last = bodyFat.last?.date, first < last else { return nil }
        return first...last
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                measurementsCard
                bodyFatCard
            }
            .padding()
        }
        .background(Color.strideBackground)
        .navigationTitle("Body trends")
        .inlineNavigationTitle()
    }

    private var measurementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Measurements").font(.headline)
            if Set(measurements.map(\.date)).count < 2 {
                ContentUnavailableView("Not enough measurements", systemImage: "ruler",
                                       description: Text("Log waist, hips or chest in Vitals on two or more days to see them change together."))
                    .frame(height: 200)
            } else {
                Chart(measurements) { p in
                    LineMark(x: .value("Date", p.date), y: .value(units.lengthUnit, p.value))
                        .foregroundStyle(by: .value("Measurement", p.series))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Date", p.date), y: .value(units.lengthUnit, p.value))
                        .foregroundStyle(by: .value("Measurement", p.series))
                }
                .chartForegroundStyleScale(["Waist": Color.orange, "Hips": Color.pink, "Chest": Color.teal])
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxisLabel(units.lengthUnit)
                .frame(height: 220)
                .accessibilityLabel("Waist, hips and chest measurements")
                changeSummary
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @ViewBuilder
    private var changeSummary: some View {
        let lines: [String] = ["Waist", "Hips", "Chest"].compactMap { name in
            let series = measurements.filter { $0.series == name }
            guard let first = series.first, let last = series.last, series.count >= 2 else { return nil }
            return String(format: "%@ %+.1f %@", name, last.value - first.value, units.lengthUnit)
        }
        if !lines.isEmpty {
            Text("Since first reading: " + lines.joined(separator: " · "))
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        }
    }

    private var bodyFatCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Body fat and weight").font(.headline)
            if let domain = fatDomain {
                Chart(bodyFat) { p in
                    LineMark(x: .value("Date", p.date), y: .value("Body fat", p.value))
                        .foregroundStyle(.purple)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Date", p.date), y: .value("Body fat", p.value))
                        .foregroundStyle(.purple)
                }
                .chartXScale(domain: domain)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxisLabel("%")
                .frame(height: 150)
                .accessibilityLabel("Body fat")
                let trend = weightTrend.filter { domain.contains($0.date) }
                if trend.count >= 2 {
                    Chart(trend) { p in
                        LineMark(x: .value("Date", p.date), y: .value("Weight", p.value))
                            .foregroundStyle(.indigo)
                            .interpolationMethod(.monotone)
                    }
                    .chartXScale(domain: domain)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartYAxisLabel(units.weightUnit)
                    .frame(height: 150)
                    .accessibilityLabel("Weight trend")
                }
                fatSummary(weightTrend: trend)
            } else {
                ContentUnavailableView("Not enough body-fat readings", systemImage: "percent",
                                       description: Text("Log body fat in Vitals on two or more days to compare it with your weight trend."))
                    .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func change(in points: [Point]) -> Double? {
        guard let first = points.first, let last = points.last, points.count >= 2 else { return nil }
        return last.value - first.value
    }

    @ViewBuilder
    private func fatSummary(weightTrend: [Point]) -> some View {
        if let firstFat = bodyFat.first, let lastFat = bodyFat.last {
            let fatChange: Double = lastFat.value - firstFat.value
            let weightChange: Double? = change(in: weightTrend)
            let weightText: String = weightChange.map { String(format: ", weight trend %+.1f %@", $0, units.weightUnit) } ?? ""
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "Body fat %+.1f points", fatChange) + weightText + " over the same period.")
                if let weightChange, weightChange < 0, fatChange < 0 {
                    Text("Both falling together: the weight you're losing is mostly fat.")
                        .foregroundStyle(Color.secondary)
                } else if let weightChange, weightChange < 0, fatChange >= 0 {
                    Text("Weight is falling faster than body fat. More protein and some strength training help keep muscle.")
                        .foregroundStyle(Color.secondary)
                }
            }
            .font(.footnote)
        }
    }
}
