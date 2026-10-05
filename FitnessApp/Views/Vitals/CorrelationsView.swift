import SwiftUI
import SwiftData
import Charts

/// Two measures side by side: sleep against the next day's eating, and sodium against
/// blood pressure. Plain comparisons, no statistics.
struct CorrelationsView: View {
    @Query(sort: \VitalsEntry.date) private var vitals: [VitalsEntry]
    @Query private var food: [FoodLogEntry]
    @Query private var checkIns: [MealCheckIn]

    private var hungerRatings: [(date: Date, rating: Int)] {
        checkIns.compactMap { c in c.hunger.map { (date: c.day, rating: $0) } }
    }

    private var hungerProteinPairs: [CorrelationCalculator.Pair] {
        CorrelationCalculator.hungerVersus(food.map { (date: $0.date, value: $0.protein) }, hunger: hungerRatings)
    }

    private var hungerCaloriePairs: [CorrelationCalculator.Pair] {
        CorrelationCalculator.hungerVersus(food.map { (date: $0.date, value: $0.calories) }, hunger: hungerRatings)
    }

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
                PairChartCard(title: "Protein and hunger",
                              xLabel: "Protein (g)", yLabel: "Hunger (1–5)",
                              pairs: hungerProteinPairs, tint: .blue,
                              emptyText: "Rate hunger before meals from the diary's meal menu. A few weeks shows whether higher-protein days leave you less hungry.",
                              summary: hungerSummary(hungerProteinPairs, measure: { "\(Int($0.rounded())) g of protein" }))
                PairChartCard(title: "Calories and hunger",
                              xLabel: "Calories", yLabel: "Hunger (1–5)",
                              pairs: hungerCaloriePairs, tint: .orange,
                              emptyText: "Rate hunger before meals from the diary's meal menu to see how it tracks with how much you eat.",
                              summary: hungerSummary(hungerCaloriePairs, measure: { Energy.string($0) }))
                Text("These show what happened together, not what caused what.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
            .padding()
        }
        .background(Color.strideBackground)
        .navigationTitle("Patterns")
        .inlineNavigationTitle()
    }

    private var sleepSummary: String? {
        guard let split = CorrelationCalculator.split(sleepPairs) else { return nil }
        let hours = split.medianX.formatted(.number.precision(.fractionLength(0...1)))
        let kcal = Int(abs(split.difference).rounded())
        if kcal < 50 { return "Your eating looks about the same whether you slept more or less than \(hours) h." }
        return "After nights over \(hours) h you ate about \(Energy.string(kcal)) \(split.difference < 0 ? "less" : "more") than after shorter nights."
    }

    private func hungerSummary(_ pairs: [CorrelationCalculator.Pair], measure: (Double) -> String) -> String? {
        guard let split = CorrelationCalculator.split(pairs) else { return nil }
        let threshold = measure(split.medianX)
        let change = abs(split.difference).formatted(.number.precision(.fractionLength(1)))
        if abs(split.difference) < 0.3 { return "Your hunger looks about the same on days above and below \(threshold)." }
        return "On days over \(threshold), your hunger averaged \(change) points \(split.difference < 0 ? "lower" : "higher") (out of 5)."
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
