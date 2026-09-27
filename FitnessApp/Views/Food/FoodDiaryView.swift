import SwiftUI
import SwiftData

struct FoodDiaryView: View {
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            DayDiaryView(date: date.startOfDay)
                .id(date.startOfDay)
                .safeAreaInset(edge: .top) {
                    DayStepper(date: $date)
                        .padding(.vertical, 8)
                        .background(.bar)
                }
                .navigationTitle("Food")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DayDiaryView: View {
    let date: Date

    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Query private var entries: [FoodLogEntry]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]

    @State private var addingTo: MealType?
    @State private var editing: FoodLogEntry?

    init(date: Date) {
        self.date = date
        let start = date.startOfDay
        let end = start.adding(days: 1)
        _entries = Query(filter: #Predicate<FoodLogEntry> { $0.date >= start && $0.date < end },
                         sort: \FoodLogEntry.date)
    }

    private var currentKg: Double { weights.first?.weightKg ?? profile.startWeightKg }
    private var target: Int { profile.calorieTarget(currentWeightKg: currentKg) }
    private var macroTargets: MacroTargets { profile.macroTargets(currentWeightKg: currentKg) }

    private var consumed: Double { entries.reduce(0) { $0 + $1.calories } }
    private var protein: Double { entries.reduce(0) { $0 + $1.protein } }
    private var carbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    private var fat: Double { entries.reduce(0) { $0 + $1.fat } }

    private func entries(for meal: MealType) -> [FoodLogEntry] {
        entries.filter { $0.mealType == meal }
    }

    var body: some View {
        List {
            Section {
                summary
            }
            ForEach(MealType.allCases) { meal in
                let items = entries(for: meal)
                Section {
                    ForEach(items) { entry in
                        Button { editing = entry } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.foodName).foregroundStyle(Color.primary)
                                    Text(entry.servingsLabel).font(.caption).foregroundStyle(Color.secondary)
                                }
                                Spacer()
                                Text("\(Int(entry.calories.rounded()))")
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { context.delete(items[i]) }
                        try? context.save()
                    }
                    Button {
                        addingTo = meal
                    } label: {
                        Label("Add food", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.medium))
                    }
                } header: {
                    HStack {
                        Label(meal.label, systemImage: meal.systemImage)
                        Spacer()
                        let kcal = items.reduce(0) { $0 + $1.calories }
                        if kcal > 0 {
                            Text("\(Int(kcal.rounded())) kcal")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $addingTo) { meal in
            FoodSearchView(date: date.isToday ? .now : date, mealType: meal)
        }
        .sheet(item: $editing) { entry in
            EditLogEntrySheet(entry: entry)
        }
    }

    private var summary: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: target > 0 ? consumed / Double(target) : 0, lineWidth: 10)
                    VStack(spacing: 0) {
                        Text("\(Int(consumed.rounded()))")
                            .font(.headline.monospacedDigit())
                        Text("of \(target)")
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .frame(width: 84, height: 84)
                VStack(spacing: 8) {
                    MacroBar(name: "Protein", consumed: protein, target: macroTargets.protein, color: .blue)
                    MacroBar(name: "Carbs", consumed: carbs, target: macroTargets.carbs, color: .orange)
                    MacroBar(name: "Fat", consumed: fat, target: macroTargets.fat, color: .pink)
                }
            }
            let remaining = Double(target) - consumed
            Text(remaining >= 0 ? "\(Int(remaining.rounded())) kcal remaining" : "\(Int((-remaining).rounded())) kcal over budget")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(remaining >= 0 ? Color.primary : Color.orange)
        }
        .padding(.vertical, 4)
    }
}

struct EditLogEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let entry: FoodLogEntry

    @State private var servings: Double = 1
    @State private var meal: MealType = .snack
    @State private var loaded = false

    private var perServing: (kcal: Double, p: Double, c: Double, f: Double) {
        let s = max(entry.servings, 0.01)
        return (entry.calories / s, entry.protein / s, entry.carbs / s, entry.fat / s)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(entry.foodName) {
                    Picker("Meal", selection: $meal) {
                        ForEach(MealType.allCases) { Text($0.label).tag($0) }
                    }
                    ServingsControl(servings: $servings, description: entry.servingDescription)
                    LabeledContent("Calories", value: "\(Int((perServing.kcal * servings).rounded())) kcal")
                    MacroSummary(protein: perServing.p * servings, carbs: perServing.c * servings, fat: perServing.f * servings)
                }
                Section {
                    Button("Delete entry", role: .destructive) {
                        context.delete(entry)
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let p = perServing
                        entry.servings = servings
                        entry.calories = p.kcal * servings
                        entry.protein = p.p * servings
                        entry.carbs = p.c * servings
                        entry.fat = p.f * servings
                        entry.mealType = meal
                        try? context.save()
                        dismiss()
                    }
                    .disabled(servings <= 0)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                servings = entry.servings
                meal = entry.mealType
            }
        }
        .presentationDetents([.medium])
    }
}

struct ServingsControl: View {
    @Binding var servings: Double
    var description: String

    private let presets: [Double] = [0.5, 1, 1.5, 2, 3]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Servings")
                Spacer()
                TextField("Servings", value: $servings, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
                Stepper("", value: $servings, in: 0.25...50, step: 0.25).labelsHidden()
            }
            if !description.isEmpty {
                Text("1 serving = \(description)")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            HStack {
                ForEach(presets, id: \.self) { preset in
                    Button(preset.cleanString) { servings = preset }
                        .buttonStyle(.bordered)
                        .tint(servings == preset ? Color.accentColor : Color.secondary)
                        .controlSize(.small)
                }
            }
        }
    }
}
