import SwiftUI
import Charts

/// Steps and active energy over the last week or month, opened from the Activity card.
struct ActivityTrendView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ActivityTrend.stepGoalKey) private var stepGoal = 0
    @State private var range = Range.week
    @State private var days: [ActivityDay] = []
    @State private var loading = true

    enum Range: Int, CaseIterable, Identifiable {
        case week = 7, month = 30
        var id: Int { rawValue }
        var title: String { self == .week ? String(localized: "7 days") : String(localized: "30 days") }
    }

    private var summary: ActivityTrend.Summary { ActivityTrend.summary(days, goal: stepGoal) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Range", selection: $range) {
                        ForEach(Range.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                if loading {
                    Section { ProgressView().frame(maxWidth: .infinity) }
                } else if summary.days == 0 {
                    Section {
                        Text("Apple Health has no steps or active energy for this period yet.")
                            .foregroundStyle(Color.secondary)
                    }
                } else {
                    Section("Steps") { stepsChart }
                    Section("Active energy") { energyChart }
                    Section("Averages") {
                        LabeledContent("Steps per day", value: summary.averageSteps.formatted())
                        LabeledContent("Active energy per day", value: Energy.string(summary.averageActiveKcal))
                        if let atGoal = summary.daysAtGoal {
                            LabeledContent("Days at your step goal", value: "\(atGoal) of \(summary.days)")
                        }
                        if let best = summary.bestDay {
                            LabeledContent("Most steps", value: "\(best.steps.formatted()) on \(best.date.formatted(.dateTime.month().day()))")
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .inlineNavigationTitle()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: range) { await load() }
        }
        .accessibilityIdentifier("activityTrend")
    }

    private var stepsChart: some View {
        Chart {
            ForEach(days) { day in
                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Steps", day.steps))
                    .foregroundStyle(stepGoal > 0 && day.steps >= stepGoal ? Color.green : Color.green.opacity(0.5))
            }
            if stepGoal > 0 {
                RuleMark(y: .value("Goal", stepGoal))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal \(stepGoal.formatted())").font(.caption2).foregroundStyle(Color.secondary)
                    }
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Steps per day")
        .accessibilityValue("Average \(summary.averageSteps.formatted()) steps a day")
    }

    private var energyChart: some View {
        Chart(days) { day in
            BarMark(x: .value("Day", day.date, unit: .day),
                    y: .value("Active energy", EnergyUnit.current.value(kcal: day.activeKcal)))
                .foregroundStyle(Color.orange)
        }
        .chartYAxisLabel(Energy.unit)
        .frame(height: 160)
        .accessibilityLabel("Active energy per day")
        .accessibilityValue("Average \(Energy.string(summary.averageActiveKcal)) a day")
    }

    private func load() async {
        loading = true
        days = await HealthKitManager.shared.dailyActivity(days: range.rawValue)
        loading = false
    }
}
