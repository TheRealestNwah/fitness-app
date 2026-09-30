import SwiftUI
import SwiftData
import Charts

/// Two measures side by side: sleep against the next day's eating, and sodium against
/// blood pressure. Plain comparisons, no statistics.
struct CorrelationsView: View {
    @Query(sort: \VitalsEntry.date) private var vitals: [VitalsEntry]
    @Query private var food: [FoodLogEntry]

    private var sleepPairs: [CorrelationCalculator.Pair] {
        CorrelationCalculator.sleepVersusIntake(
            sleep: vitals.compactMap { v in v.sleepHours.map { (date: v.date, hours: $0) } },
            food: food.map { (date: $0.date, calories: $0.calories) })
    }

    private var sodiumPairs: [CorrelationCalculator.Pair] {
        CorrelationCalculator.sodiumVersusSystolic(
            readings: vitals.compactMap { v in v.systolic.map { (date: v.date, systolic: Double($0)) } },
            food: food.map { (date: $0.date, sodiumMg: $0.sodium) })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PairChartCard(title: "Sleep and the next day's eating",
                              xLabel: "Sleep (h)", yLabel: "Calories",
                              pairs: sleepPairs, tint: .indigo,
                              emptyText: "Log sleep in Vitals and food on the same days. A few weeks of both shows whether short nights lead to bigger days.",
                              summary: sleepSummary)
                PairChartCard(title: "Sodium and blood pressure",
                              xLabel: "Sodium the day before (mg)", yLabel: "Systolic (mmHg)",
                              pairs: sodiumPairs, tint: .red,
                              emptyText: "Log blood pressure in Vitals, and foods that list sodium the day before. Scanned packaged foods usually do.",
                              summary: sodiumSummary)
                Text("These show what happened together, not what caused what.")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Patterns")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sleepSummary: String? {
        guard let split = CorrelationCalculator.split(sleepPairs) else { return nil }
        let hours = split.medianX.formatted(.number.precision(.fractionLength(0...1)))
        let kcal = Int(abs(split.difference).rounded())
        if kcal < 50 { return "Your eating looks about the same whether you slept more or less than \(hours) h." }
        return "After nights over \(hours) h you ate about \(Energy.string(kcal)) \(split.difference < 0 ? "less" : "more") than after shorter nights."
    }

    private var sodiumSummary: String? {
        guard let split = CorrelationCalculator.split(sodiumPairs) else { return nil }
        let mg = Int(split.medianX.rounded())
        let mmHg = Int(abs(split.difference).rounded())
        if mmHg < 3 { return "Your systolic looks about the same after days above and below \(mg) mg of sodium." }
        return "After days over \(mg) mg of sodium your systolic averaged \(mmHg) mmHg \(split.difference > 0 ? "higher" : "lower")."
    }
}

private struct PairChartCard: View {
    var title: String
    var xLabel: String
    var yLabel: String
    var pairs: [CorrelationCalculator.Pair]
    var tint: Color
    var emptyText: String
    var summary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            if pairs.count < CorrelationCalculator.minimumForChart {
                ContentUnavailableView("Not enough days yet", systemImage: "chart.dots.scatter",
                                       description: Text(emptyText))
                    .frame(height: 200)
            } else {
                Chart(pairs, id: \.date) { pair in
                    PointMark(x: .value(xLabel, pair.x), y: .value(yLabel, pair.y))
                        .foregroundStyle(tint)
                }
                .chartXScale(domain: .automatic(includesZero: false))
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxisLabel(xLabel)
                .chartYAxisLabel(yLabel)
                .frame(height: 220)
                .accessibilityLabel(title)
                Text(summary ?? "\(pairs.count) days so far. A pattern summary appears after \(CorrelationCalculator.minimumForSummary).")
                    .font(.subheadline)
                    .foregroundStyle(summary == nil ? Color.secondary : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
