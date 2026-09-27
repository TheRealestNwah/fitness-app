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
    @Environment(UndoCenter.self) private var undoCenter
    @Query private var entries: [FoodLogEntry]
    @Query private var yesterdayEntries: [FoodLogEntry]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]

    @State private var addingTo: MealType?
    @State private var editing: FoodLogEntry?
    @State private var savingFavourite: MealType?

    init(date: Date) {
        self.date = date
        let start = date.startOfDay
        let end = start.adding(days: 1)
        let yesterday = start.adding(days: -1)
        _entries = Query(filter: #Predicate<FoodLogEntry> { $0.date >= start && $0.date < end },
                         sort: \FoodLogEntry.date)
        _yesterdayEntries = Query(filter: #Predicate<FoodLogEntry> { $0.date >= yesterday && $0.date < start },
                                  sort: \FoodLogEntry.date)
    }

    private var currentKg: Double { weights.first?.weightKg ?? profile.startWeightKg }
    private var target: Int {
        let base = profile.calorieTarget(currentWeightKg: currentKg)
        return date.isToday ? base + HealthKitManager.shared.activeEnergyCredit : base
    }
    private var macroTargets: MacroTargets { profile.macroTargets(currentWeightKg: currentKg) }

    private var consumed: Double { entries.reduce(0) { $0 + $1.calories } }
    private var protein: Double { entries.reduce(0) { $0 + $1.protein } }
    private var carbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    private var fat: Double { entries.reduce(0) { $0 + $1.fat } }

    private func entries(for meal: MealType) -> [FoodLogEntry] {
        entries.filter { $0.mealType == meal }
    }

    private func yesterday(for meal: MealType) -> [FoodLogEntry] {
        yesterdayEntries.filter { $0.mealType == meal }
    }

    /// Re-logs yesterday's lines for this meal onto the current day.
    private func copyYesterday(_ meal: MealType) {
        let stamp = meal.logDate(on: date)
        for e in yesterday(for: meal) {
            context.insertDiaryEntry(FoodLogEntry(date: stamp, mealType: meal, foodName: e.foodName, servings: e.servings,
                                        servingDescription: e.servingDescription, calories: e.calories,
                                        protein: e.protein, carbs: e.carbs, fat: e.fat, foodItemID: e.foodItemID,
                                        fiber: e.fiber, sugar: e.sugar, sodium: e.sodium))
        }
        try? context.save()
    }

    private func clear(_ meal: MealType) {
        context.deleteDiaryEntries(entries(for: meal), undo: undoCenter)
    }

    var body: some View {
        List {
            Section {
                summary
            }
            if entries.isEmpty {
                let meal = MealType.current()
                let cal = Calendar.current
                let when = cal.isDateInToday(date) || cal.isDateInYesterday(date)
                    ? date.relativeDayLabel.lowercased() : "on \(date.relativeDayLabel)"
                Section {
                    ContentUnavailableView {
                        Label("Nothing logged \(when)", systemImage: "fork.knife")
                    } description: {
                        Text("Log what you eat to see calories and macros against your target.")
                    } actions: {
                        Button("Log \(meal.label.lowercased())") { addingTo = meal }
                            .buttonStyle(.borderedProminent)
                    }
                }
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
                        context.deleteDiaryEntries(offsets.map { items[$0] }, undo: undoCenter)
                    }
                    Button {
                        addingTo = meal
                    } label: {
                        Label("Add food", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    let fromYesterday = yesterday(for: meal)
                    if items.isEmpty, !fromYesterday.isEmpty {
                        let kcal = fromYesterday.reduce(0) { $0 + $1.calories }
                        Button {
                            copyYesterday(meal)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Copy yesterday's \(meal.label.lowercased())")
                                        .font(.subheadline.weight(.medium))
                                    Text("\(fromYesterday.count) item\(fromYesterday.count == 1 ? "" : "s") · \(Int(kcal.rounded())) kcal")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                            } icon: {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Label(meal.label, systemImage: meal.systemImage)
                        Spacer()
                        let kcal = items.reduce(0) { $0 + $1.calories }
                        if kcal > 0 {
                            Text("\(Int(kcal.rounded())) kcal")
                        }
                        Menu {
                            Button {
                                copyYesterday(meal)
                            } label: {
                                Label("Copy from yesterday", systemImage: "arrow.uturn.backward")
                            }
                            .disabled(yesterday(for: meal).isEmpty)
                            Button {
                                savingFavourite = meal
                            } label: {
                                Label("Save as favourite meal", systemImage: "star")
                            }
                            .disabled(items.isEmpty)
                            if !items.isEmpty {
                                Button(role: .destructive) {
                                    clear(meal)
                                } label: {
                                    Label("Clear \(meal.label.lowercased())", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.body)
                                .accessibilityLabel("\(meal.label) options")
                        }
                        .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $addingTo) { meal in
            FoodSearchView(date: date, mealType: meal)
        }
        .sheet(item: $editing) { entry in
            EditLogEntrySheet(entry: entry)
        }
        .sheet(item: $savingFavourite) { meal in
            SaveFavouriteMealSheet(mealType: meal, entries: entries(for: meal))
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
            NutrientRow(fiber: entries.reduce(0) { $0 + $1.fiber },
                        sugar: entries.reduce(0) { $0 + $1.sugar },
                        sodium: entries.reduce(0) { $0 + $1.sodium },
                        profile: profile)
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
    @Environment(UndoCenter.self) private var undoCenter
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
                        context.deleteDiaryEntries([entry], undo: undoCenter)
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
                        let ratio = servings / max(entry.servings, 0.01)
                        entry.fiber *= ratio
                        entry.sugar *= ratio
                        entry.sodium *= ratio
                        entry.servings = servings
                        entry.calories = p.kcal * servings
                        entry.protein = p.p * servings
                        entry.carbs = p.c * servings
                        entry.fat = p.f * servings
                        entry.mealType = meal
                        try? context.save()
                        HealthKitManager.shared.recordDiaryEntry(entry)
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

/// Names a set of diary lines and stores them as a `SavedMeal`.
struct SaveFavouriteMealSheet: View {
    let mealType: MealType
    let entries: [FoodLogEntry]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    private var totalCalories: Double { entries.reduce(0) { $0 + $1.calories } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Weekday breakfast)", text: $name)
                } footer: {
                    Text("Favourite meals appear at the top of food search and log every line with one tap.")
                }
                Section("\(entries.count) item\(entries.count == 1 ? "" : "s") · \(Int(totalCalories.rounded())) kcal") {
                    ForEach(entries) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.foodName)
                                Text(e.servingsLabel).font(.caption).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Text("\(Int(e.calories.rounded()))")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Save favourite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let meal = SavedMeal(name: name.trimmingCharacters(in: .whitespaces),
                                             mealType: mealType,
                                             items: entries.map(SavedMealItem.init(entry:)))
                        context.insert(meal)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || entries.isEmpty)
                }
            }
            .onAppear {
                if name.isEmpty {
                    name = "\(mealType.label) · \(Date.now.formatted(.dateTime.weekday(.abbreviated)))"
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
