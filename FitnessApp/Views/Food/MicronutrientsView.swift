import SwiftData
import SwiftUI

/// Whether vitamins and minerals are tracked, entered on custom foods and shown in the diary.
enum MicronutrientSettings {
    static let storageKey = "trackMicronutrients"
}

/// Vitamins and minerals for a day or the week to date, against reference intakes for the person's age and sex.
struct MicronutrientsView: View {
    let date: Date

    @Environment(UserProfile.self) private var profile
    @Query private var weekEntries: [FoodLogEntry]
    @State private var showWeek = false

    init(date: Date) {
        self.date = date
        let end = date.startOfDay.adding(days: 1)
        let start = end.adding(days: -7)
        _weekEntries = Query(filter: #Predicate<FoodLogEntry> { $0.date >= start && $0.date < end },
                             sort: \FoodLogEntry.date)
    }

    private var summary: MicronutrientSummary {
        if showWeek { return MicronutrientSummary.make(entries: weekEntries, days: 7) }
        let day = weekEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        return MicronutrientSummary.make(entries: day)
    }

    var body: some View {
        let summary = summary
        let references = ReferenceIntakes.targets(sex: profile.sex, age: profile.age)
        List {
            Section {
                Picker("Period", selection: $showWeek) {
                    Text("Day").tag(false)
                    Text("Last 7 days").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("micronutrientPeriod")
            } footer: {
                Text(showWeek ? "Daily average over the last 7 days. \(summary.coverageText)."
                              : "\(summary.coverageText).")
            }
            Section {
                ForEach(Micronutrient.allCases) { nutrient in
                    MicronutrientRow(nutrient: nutrient,
                                     amount: summary.perDay(nutrient),
                                     reference: references[nutrient] ?? 0,
                                     hasData: summary.foodsWithData > 0 && summary.totals[nutrient] > 0)
                }
            } footer: {
                Text("Reference intakes are the US recommended daily amounts for your age and sex. Foods that don't list a nutrient count as unknown rather than zero, so totals can read low. Talk to your doctor before changing supplements.")
            }
        }
        .navigationTitle("Vitamins and minerals")
        .inlineNavigationTitle()
    }
}

private struct MicronutrientRow: View {
    let nutrient: Micronutrient
    let amount: Double
    let reference: Double
    let hasData: Bool

    private var fraction: Double { reference > 0 ? amount / reference : 0 }

    private var amountText: String {
        let value = amount.formatted(.number.precision(.fractionLength(0...1)))
        let goal = reference.formatted(.number.precision(.fractionLength(0...1)))
        return "\(value) / \(goal) \(nutrient.unit)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(nutrient.name)
                Spacer()
                Text(hasData ? amountText : "No data")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(hasData ? Color.primary : Color.secondary)
            }
            if hasData {
                ProgressView(value: min(fraction, 1))
                    .tint(fraction >= 1 ? .green : .accentColor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nutrient.name)
        .accessibilityValue(hasData ? "\(amountText), \(Int((fraction * 100).rounded())) percent" : "No data")
    }
}
