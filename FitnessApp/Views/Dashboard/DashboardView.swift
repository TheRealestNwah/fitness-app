import SwiftUI
import SwiftData

struct DashboardView: View {
    var selectTab: (MainTabView.Tab) -> Void

    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context

    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \VitalsEntry.date, order: .reverse) private var vitals: [VitalsEntry]
    @Query private var todaysFood: [FoodLogEntry]
    @Query private var todaysWater: [WaterEntry]
    @Query private var recentFood: [FoodLogEntry]
    @Query private var recentWeights: [WeightEntry]
    @Query private var todaysPlan: [MealPlanEntry]

    @State private var showAddWeight = false
    @State private var showAddFood = false
    @State private var showAddVitals = false
    @State private var showSettings = false

    init(selectTab: @escaping (MainTabView.Tab) -> Void) {
        self.selectTab = selectTab
        let start = Calendar.current.startOfDay(for: .now)
        let end = start.adding(days: 1)
        let sixtyDaysAgo = start.adding(days: -60)
        _todaysFood = Query(filter: #Predicate<FoodLogEntry> { $0.date >= start && $0.date < end },
                            sort: \FoodLogEntry.date)
        _todaysWater = Query(filter: #Predicate<WaterEntry> { $0.date >= start && $0.date < end })
        _recentFood = Query(filter: #Predicate<FoodLogEntry> { $0.date >= sixtyDaysAgo })
        _recentWeights = Query(filter: #Predicate<WeightEntry> { $0.date >= sixtyDaysAgo })
        _todaysPlan = Query(filter: #Predicate<MealPlanEntry> { $0.day >= start && $0.day < end })
    }

    // MARK: Derived

    private var units: Units { profile.units }
    private var currentKg: Double { weights.first?.weightKg ?? profile.startWeightKg }
    private var calorieTarget: Int { profile.calorieTarget(currentWeightKg: currentKg) }
    private var macroTargets: MacroTargets { profile.macroTargets(currentWeightKg: currentKg) }

    private var consumed: Double { todaysFood.reduce(0) { $0 + $1.calories } }
    private var protein: Double { todaysFood.reduce(0) { $0 + $1.protein } }
    private var carbs: Double { todaysFood.reduce(0) { $0 + $1.carbs } }
    private var fat: Double { todaysFood.reduce(0) { $0 + $1.fat } }
    private var waterMl: Double { todaysWater.reduce(0) { $0 + $1.amountMl } }

    private var streak: Int {
        NutritionCalculator.streak(logDates: recentFood.map(\.date) + recentWeights.map(\.date))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let base: String
        switch hour {
        case 5..<12: base = "Good morning"
        case 12..<17: base = "Good afternoon"
        default: base = "Good evening"
        }
        return profile.name.isEmpty ? base : "\(base), \(profile.name)"
    }

    private var tip: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return SeedData.tips[day % SeedData.tips.count]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    calorieCard
                    quickActions
                    weightCard
                    waterCard
                    if !todaysPlan.isEmpty { planCard }
                    vitalsCard
                    tipCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showAddWeight) { AddWeightSheet() }
            .sheet(isPresented: $showAddFood) { FoodSearchView(date: .now, mealType: MealType.current()) }
            .sheet(isPresented: $showAddVitals) { AddVitalsSheet() }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.title2.bold())
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if streak > 0 {
                Label("\(streak) day\(streak == 1 ? "" : "s")", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }
        }
    }

    private var calorieCard: some View {
        let remaining = Double(calorieTarget) - consumed
        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                ZStack {
                    ProgressRing(progress: Double(calorieTarget) > 0 ? consumed / Double(calorieTarget) : 0, lineWidth: 14)
                    VStack(spacing: 2) {
                        Text("\(Int(abs(remaining).rounded()))")
                            .font(.title.bold().monospacedDigit())
                        Text(remaining >= 0 ? "left" : "over")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("Eaten", value: "\(Int(consumed.rounded()))")
                    LabeledContent("Budget", value: "\(calorieTarget)")
                    Divider()
                    MacroBar(name: "Protein", consumed: protein, target: macroTargets.protein, color: .blue)
                    MacroBar(name: "Carbs", consumed: carbs, target: macroTargets.carbs, color: .orange)
                    MacroBar(name: "Fat", consumed: fat, target: macroTargets.fat, color: .pink)
                }
                .font(.subheadline.monospacedDigit())
            }
            Button {
                selectTab(.food)
            } label: {
                HStack {
                    Text(todaysFood.isEmpty ? "Nothing logged yet" : "\(todaysFood.count) item\(todaysFood.count == 1 ? "" : "s") logged")
                    Spacer()
                    Text("Open diary")
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline)
            }
        }
        .card()
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionButton(title: "Log food", systemImage: "fork.knife", tint: .green) { showAddFood = true }
            QuickActionButton(title: "Weigh in", systemImage: "scalemass", tint: .indigo) { showAddWeight = true }
            QuickActionButton(title: "Vitals", systemImage: "heart.fill", tint: .red) { showAddVitals = true }
            QuickActionButton(title: "Water", systemImage: "drop.fill", tint: .cyan) { addWater() }
        }
    }

    private var weightCard: some View {
        let lost = profile.startWeightKg - currentKg
        let remaining = max(currentKg - profile.goalWeightKg, 0)
        let total = max(profile.startWeightKg - profile.goalWeightKg, 0.001)
        let progress = min(max(lost / total, 0), 1)
        let projected = NutritionCalculator.projectedGoalDate(currentKg: currentKg, goalKg: profile.goalWeightKg, weeklyLossKg: profile.weeklyLossKg)
        let daysSinceWeighIn = weights.first.map { Calendar.current.dateComponents([.day], from: $0.date.startOfDay, to: Date.now.startOfDay).day ?? 0 }

        return Button {
            selectTab(.weight)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Weight", systemImage: "scalemass.fill")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(units.weightString(kg: currentKg))
                        .font(.title.bold().monospacedDigit())
                    Text(units.weightString(kg: -lost, signed: true))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(lost >= 0 ? .green : .orange)
                    Spacer()
                    if let days = daysSinceWeighIn, days > 0 {
                        Text(days == 1 ? "Yesterday" : "\(days) days ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ProgressView(value: progress)
                    .tint(.indigo)
                HStack {
                    Text("\(units.weightString(kg: remaining)) to go")
                    Spacer()
                    if remaining == 0 {
                        Text("Goal reached!")
                    } else if let projected {
                        Text("ETA \(projected.formatted(.dateTime.month(.abbreviated).day()))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .card()
    }

    private var waterCard: some View {
        let goal = profile.waterGoalMl
        let glasses = Int((waterMl / units.glassMl).rounded(.down))
        let goalGlasses = Int((goal / units.glassMl).rounded(.up))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Water", systemImage: "drop.fill")
                    .font(.headline)
                Spacer()
                Text("\(units.volumeString(ml: waterMl)) / \(units.volumeString(ml: goal))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(0..<max(goalGlasses, 1), id: \.self) { i in
                    Image(systemName: i < glasses ? "drop.fill" : "drop")
                        .foregroundStyle(i < glasses ? Color.cyan : Color.secondary.opacity(0.4))
                }
                Spacer()
                Button {
                    removeWater()
                } label: {
                    Image(systemName: "minus.circle")
                }
                .disabled(todaysWater.isEmpty)
                Button {
                    addWater()
                } label: {
                    Label("Glass", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
        }
        .card()
    }

    private var planCard: some View {
        let planned = todaysPlan.reduce(0) { $0 + $1.totalCalories }
        return Button {
            selectTab(.plan)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Today's plan", systemImage: "calendar")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(planned.rounded())) kcal planned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(todaysPlan.sorted { $0.mealType.order < $1.mealType.order }) { entry in
                    HStack {
                        Image(systemName: entry.mealType.systemImage)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(entry.title)
                            .lineLimit(1)
                        Spacer()
                        if entry.isLogged {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Text("\(Int(entry.totalCalories.rounded()))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
        .buttonStyle(.plain)
        .card()
    }

    private var vitalsCard: some View {
        Button {
            selectTab(.vitals)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Vitals", systemImage: "heart.text.square.fill")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                if let bp = vitals.first(where: { $0.systolic != nil && $0.diastolic != nil }),
                   let sys = bp.systolic, let dia = bp.diastolic {
                    LabeledContent("Blood pressure", value: "\(sys)/\(dia) · \(NutritionCalculator.bloodPressureCategory(systolic: sys, diastolic: dia).rawValue)")
                }
                if let hr = vitals.first(where: { $0.restingHeartRate != nil })?.restingHeartRate {
                    LabeledContent("Resting heart rate", value: "\(hr) bpm")
                }
                if let waist = vitals.first(where: { $0.waistCm != nil })?.waistCm {
                    LabeledContent("Waist", value: units.lengthString(cm: waist))
                }
                if let sleep = vitals.first(where: { $0.sleepHours != nil })?.sleepHours {
                    LabeledContent("Sleep", value: String(format: "%.1f h", sleep))
                }
                if vitals.isEmpty {
                    Text("No vitals yet. Log blood pressure, measurements or sleep to see trends.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
        }
        .buttonStyle(.plain)
        .card()
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
            Text(tip)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Actions

    private func addWater() {
        context.insert(WaterEntry(date: .now, amountMl: units.glassMl))
        try? context.save()
    }

    private func removeWater() {
        guard let last = todaysWater.sorted(by: { $0.date < $1.date }).last else { return }
        context.delete(last)
        try? context.save()
    }
}

struct QuickActionButton: View {
    var title: String
    var systemImage: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.15), in: Circle())
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

extension MealType {
    var order: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .dinner: return 2
        case .snack: return 3
        }
    }
}
