import SwiftUI
import SwiftData
import Charts

struct WeightView: View {
    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]
    @Query private var foodLogs: [FoodLogEntry]

    @State private var showAdd = false
    @State private var editing: WeightEntry?
    @State private var range: ChartRange = .month

    enum ChartRange: String, CaseIterable, Identifiable {
        case month = "1M", quarter = "3M", half = "6M", all = "All"
        var id: String { rawValue }
        var days: Int? {
            switch self {
            case .month: return 30
            case .quarter: return 90
            case .half: return 180
            case .all: return nil
            }
        }
    }

    private var units: Units { profile.units }
    private var currentKg: Double { entries.first?.weightKg ?? profile.startWeightKg }
    private var lost: Double { profile.startWeightKg - currentKg }
    private var remaining: Double { max(currentKg - profile.goalWeightKg, 0) }
    private var bmi: Double { NutritionCalculator.bmi(weightKg: currentKg, heightCm: profile.heightCm) }

    private var chronological: [WeightEntry] { entries.reversed() }

    private var visible: [WeightEntry] {
        guard let days = range.days else { return chronological }
        let cutoff = Date.now.adding(days: -days).startOfDay
        return chronological.filter { $0.date >= cutoff }
    }

    private struct AveragePoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private var averageLine: [AveragePoint] {
        let all = chronological
        let avg = NutritionCalculator.movingAverage(all.map(\.weightKg), window: 7)
        let points = zip(all, avg).map { AveragePoint(date: $0.date, value: $1) }
        guard let days = range.days else { return points }
        let cutoff = Date.now.adding(days: -days).startOfDay
        return points.filter { $0.date >= cutoff }
    }

    private var weeklyRate: Double? {
        let cutoff = Date.now.adding(days: -28)
        let recent = chronological.filter { $0.date >= cutoff }.map { (date: $0.date, weightKg: $0.weightKg) }
        return NutritionCalculator.weeklyRate(points: recent)
    }

    private var weightDays: [WeeklyReviewCalculator.WeightDay] {
        entries.map { WeeklyReviewCalculator.WeightDay(date: $0.date, weightKg: $0.weightKg) }
    }

    private var milestones: [Milestone] {
        ProgressCalculator.milestones(startKg: profile.startWeightKg, weights: weightDays)
    }

    private var nextMilestone: (percent: Int, remainingKg: Double)? {
        ProgressCalculator.nextMilestone(startKg: profile.startWeightKg, weights: weightDays)
    }

    private var plateau: Plateau? {
        let estimate = AdaptiveTargetCalculator.estimate(
            foodLogs: foodLogs.map { WeeklyReviewCalculator.FoodDay(date: $0.date, calories: $0.calories) },
            weights: weightDays)
        return ProgressCalculator.plateau(weights: weightDays, goalKg: profile.goalWeightKg,
                                          currentTarget: profile.calorieTarget(currentWeightKg: currentKg),
                                          maintenance: estimate, weeklyLossKg: profile.weeklyLossKg,
                                          sex: profile.sex)
    }

    private var projected: Date? {
        NutritionCalculator.projectedGoalDate(currentKg: currentKg, goalKg: profile.goalWeightKg, weeklyLossKg: profile.weeklyLossKg)
    }

    private var yDomain: ClosedRange<Double> {
        let values = visible.map { units.weightValue(kg: $0.weightKg) } + [units.weightValue(kg: profile.goalWeightKg)]
        guard let lo = values.min(), let hi = values.max() else { return 0...100 }
        let pad = max((hi - lo) * 0.15, units.system == .metric ? 1 : 2)
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statsGrid
                    chartCard
                    insightsCard
                    historyList
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Weight")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddWeightSheet() }
            .sheet(item: $editing) { AddWeightSheet(entry: $0) }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(title: "Current", value: units.weightString(kg: currentKg), subtitle: entries.first.map { $0.date.relativeDayLabel }, systemImage: "scalemass.fill", tint: .indigo)
            StatTile(title: "Lost so far", value: units.weightString(kg: lost), subtitle: "from \(units.weightString(kg: profile.startWeightKg))", systemImage: "arrow.down.right", tint: lost >= 0 ? .green : .orange)
            StatTile(title: "To goal", value: units.weightString(kg: remaining), subtitle: "goal \(units.weightString(kg: profile.goalWeightKg))", systemImage: "flag.checkered", tint: .purple)
            StatTile(title: "BMI", value: String(format: "%.1f", bmi), subtitle: NutritionCalculator.bmiCategory(bmi), systemImage: "figure.stand", tint: .teal)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trend").font(.headline)
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
            if visible.count < 2 {
                ContentUnavailableView("Not enough data", systemImage: "chart.xyaxis.line",
                                       description: Text("Log a few weigh-ins to see your trend."))
                    .frame(height: 200)
            } else {
                Chart {
                    RuleMark(y: .value("Goal", units.weightValue(kg: profile.goalWeightKg)))
                        .foregroundStyle(.purple.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Goal").font(.caption2).foregroundStyle(.purple)
                        }
                    ForEach(visible) { entry in
                        PointMark(x: .value("Date", entry.date),
                                  y: .value("Weight", units.weightValue(kg: entry.weightKg)))
                            .foregroundStyle(.indigo.opacity(0.5))
                            .symbolSize(30)
                    }
                    ForEach(averageLine) { point in
                        LineMark(x: .value("Date", point.date),
                                 y: .value("7-day avg", point.value))
                            .foregroundStyle(.indigo)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                .chartYScale(domain: yDomain)
                .chartYAxisLabel(units.weightUnit)
                .frame(height: 220)
                HStack(spacing: 16) {
                    Label("Weigh-ins", systemImage: "circle.fill").foregroundStyle(.indigo.opacity(0.5))
                    Label("7-day average", systemImage: "line.diagonal").foregroundStyle(.indigo)
                }
                .font(.caption)
            }
        }
        .card()
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insights").font(.headline)
            if let rate = weeklyRate, entries.count >= 3 {
                let losing = rate < 0
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: losing ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                        .foregroundStyle(losing ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Averaging \(units.weightString(kg: abs(rate), decimals: 2)) per week \(losing ? "lost" : "gained") over the last 4 weeks.")
                        Text("Your plan aims for \(units.weightString(kg: profile.weeklyLossKg, decimals: 2)) per week.")
                            .foregroundStyle(Color.secondary)
                    }
                }
                .font(.subheadline)
            } else {
                Text("Keep logging for a couple of weeks and we'll show your real rate of loss here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            if let latest = milestones.last {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                    Text("\(latest.percent)% of your starting weight lost, reached \(latest.reachedOn.formatted(date: .abbreviated, time: .omitted)).")
                }
                .font(.subheadline)
            }
            if let next = nextMilestone, remaining > 0 {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "flag.checkered").foregroundStyle(.indigo)
                    Text("\(units.weightString(kg: next.remainingKg)) on your 7-day average to reach \(next.percent)%.")
                }
                .font(.subheadline)
            }
            if let plateau {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "chart.line.flattrend.xyaxis").foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your average has held steady for \(plateau.days) days.")
                        if let first = plateau.suggestions.first {
                            Text(first).foregroundStyle(Color.secondary)
                        }
                    }
                }
                .font(.subheadline)
            }
            if let projected, remaining > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.checkmark").foregroundStyle(.purple)
                    Text("On plan, you'll reach \(units.weightString(kg: profile.goalWeightKg)) around \(projected.formatted(date: .abbreviated, time: .omitted)).")
                }
                .font(.subheadline)
            } else if remaining == 0 {
                Label("You've reached your goal weight. Consider setting a maintenance target in Settings.", systemImage: "party.popper.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History").font(.headline)
            if entries.isEmpty {
                Text("No weigh-ins yet.").foregroundStyle(Color.secondary)
            }
            ForEach(Array(entries.enumerated()), id: \.element.uuid) { index, entry in
                let previous = index + 1 < entries.count ? entries[index + 1].weightKg : nil
                Button { editing = entry } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            if !entry.note.isEmpty {
                                Text(entry.note).font(.caption).foregroundStyle(Color.secondary)
                            }
                        }
                        Spacer()
                        if let previous {
                            let delta = entry.weightKg - previous
                            Text(units.weightString(kg: delta, signed: true))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(delta <= 0 ? .green : .orange)
                        }
                        Text(units.weightString(kg: entry.weightKg))
                            .font(.body.monospacedDigit().weight(.medium))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 6)
                .contextMenu {
                    Button(role: .destructive) { delete(entry) } label: { Label("Delete", systemImage: "trash") }
                }
                if index < entries.count - 1 { Divider() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func delete(_ entry: WeightEntry) {
        context.delete(entry)
        try? context.save()
    }
}

struct AddWeightSheet: View {
    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]

    var entry: WeightEntry?

    @State private var date = Date.now
    @State private var weight: Double = 0
    @State private var note = ""
    @State private var loaded = false

    private var units: Units { profile.units }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Weight", value: $weight, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.title2.monospacedDigit())
                        Text(units.weightUnit).foregroundStyle(Color.secondary)
                    }
                    Stepper("Adjust", value: $weight, in: 20...400, step: 0.1)
                        .labelsHidden()
                }
                Section {
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                    TextField("Note (optional)", text: $note)
                }
                if entry != nil {
                    Section {
                        Button("Delete weigh-in", role: .destructive) {
                            if let entry { context.delete(entry) }
                            try? context.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(entry == nil ? "Weigh in" : "Edit weigh-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(weight <= 0)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let entry {
                    date = entry.date
                    weight = (units.weightValue(kg: entry.weightKg) * 10).rounded() / 10
                    note = entry.note
                } else {
                    let latest = entries.first?.weightKg ?? profile.startWeightKg
                    weight = (units.weightValue(kg: latest) * 10).rounded() / 10
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let kg = units.kg(fromDisplayWeight: weight)
        if let entry {
            entry.date = date
            entry.weightKg = kg
            entry.note = note
        } else {
            let entry = WeightEntry(date: date, weightKg: kg, note: note)
            context.insert(entry)
            if HealthSettings.isEnabled, HealthKitManager.isAvailable {
                Task { @MainActor in
                    if let id = try? await HealthKitManager.shared.saveWeight(kg: kg, date: date) {
                        entry.sourceID = id.uuidString
                        try? context.save()
                    }
                }
            }
        }
        try? context.save()
        dismiss()
    }
}
