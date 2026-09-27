import SwiftUI
import SwiftData

struct MealPlanView: View {
    @State private var mode: Mode = .planner

    enum Mode: String, CaseIterable, Identifiable {
        case planner = "Planner"
        case recipes = "Recipes"
        case grocery = "Groceries"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .planner: PlannerView()
                case .recipes: RecipeLibraryView()
                case .grocery: GroceryListView()
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .navigationTitle("Meal plan")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }
}

// MARK: - Week planner

struct PlannerView: View {
    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter
    @Query(sort: \MealPlanEntry.day) private var allEntries: [MealPlanEntry]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var recipes: [Recipe]

    @State private var selectedDay = Date.now.startOfDay
    @State private var pickingFor: MealType?
    @State private var showAutoFillConfirm = false

    private var currentKg: Double { weights.first?.weightKg ?? profile.startWeightKg }
    private var target: Int { profile.calorieTarget(currentWeightKg: currentKg) }

    private var weekDays: [Date] {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: selectedDay)?.start ?? selectedDay
        return (0..<7).map { start.adding(days: $0) }
    }

    private var dayEntries: [MealPlanEntry] {
        allEntries.filter { Calendar.current.isDate($0.day, inSameDayAs: selectedDay) }
    }

    private func entries(for meal: MealType) -> [MealPlanEntry] {
        dayEntries.filter { $0.mealType == meal }
    }

    private func calories(on day: Date) -> Double {
        allEntries.filter { Calendar.current.isDate($0.day, inSameDayAs: day) }.reduce(0) { $0 + $1.totalCalories }
    }

    private var plannedCalories: Double { dayEntries.reduce(0) { $0 + $1.totalCalories } }

    private var weekIsEmpty: Bool {
        guard let start = weekDays.first else { return true }
        let end = start.adding(days: 7)
        return !allEntries.contains { $0.day >= start && $0.day < end }
    }

    var body: some View {
        List {
            Section {
                weekStrip
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear)
            }
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(plannedCalories.rounded())) of \(target) kcal planned")
                            .font(.subheadline.weight(.medium))
                        MacroSummary(protein: dayEntries.reduce(0) { $0 + $1.totalProtein },
                                     carbs: dayEntries.reduce(0) { $0 + $1.totalCarbs },
                                     fat: dayEntries.reduce(0) { $0 + $1.totalFat })
                    }
                    Spacer()
                    Menu {
                        Button { autoFill(replace: false) } label: { Label("Fill empty meals", systemImage: "wand.and.stars") }
                        Button { showAutoFillConfirm = true } label: { Label("Replace whole day", systemImage: "arrow.clockwise") }
                        Button { copyToTomorrow() } label: { Label("Copy day to tomorrow", systemImage: "doc.on.doc") }
                        if !dayEntries.isEmpty {
                            Button(role: .destructive) { clearDay() } label: { Label("Clear day", systemImage: "trash") }
                        }
                    } label: {
                        Label("Auto-plan", systemImage: "wand.and.stars")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }
            }
            if weekIsEmpty {
                Section {
                    ContentUnavailableView {
                        Label("Nothing planned this week", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("Auto-plan fills each meal with a recipe sized to your calorie target. You can swap anything afterwards.")
                    } actions: {
                        Button("Auto-plan \(selectedDay.relativeDayLabel)") { autoFill(replace: false) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            ForEach(MealType.allCases) { meal in
                let items = entries(for: meal)
                Section {
                    ForEach(items) { entry in
                        PlanEntryRow(entry: entry, onLog: { log(entry) })
                    }
                    .onDelete { offsets in
                        context.deletePlanEntries(offsets.map { items[$0] }, undo: undoCenter)
                    }
                    Button { pickingFor = meal } label: {
                        Label("Add to \(meal.label.lowercased())", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.medium))
                    }
                } header: {
                    HStack {
                        Label(meal.label, systemImage: meal.systemImage)
                        Spacer()
                        Text("target ~\(Int(Double(target) * meal.budgetShare)) kcal")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $pickingFor) { meal in
            PlanItemPicker(day: selectedDay, mealType: meal)
        }
        .confirmationDialog("Replace everything planned for \(selectedDay.relativeDayLabel)?", isPresented: $showAutoFillConfirm, titleVisibility: .visible) {
            Button("Replace", role: .destructive) { autoFill(replace: true) }
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 4) {
            Button { selectedDay = selectedDay.adding(days: -7) } label: {
                Image(systemName: "chevron.left").frame(width: 24, height: 44)
            }
            ForEach(weekDays, id: \.self) { day in
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                let kcal = calories(on: day)
                Button { selectedDay = day } label: {
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2)
                        Text(day.formatted(.dateTime.day()))
                            .font(.subheadline.weight(.semibold))
                        Circle()
                            .fill(kcal > 0 ? Color.accentColor : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        if day.isToday {
                            RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Button { selectedDay = selectedDay.adding(days: 7) } label: {
                Image(systemName: "chevron.right").frame(width: 24, height: 44)
            }
        }
    }

    // MARK: Actions

    private func log(_ entry: MealPlanEntry) {
        let logDate = entry.mealType.logDate(on: selectedDay)
        context.insertDiaryEntry(FoodLogEntry(date: logDate, mealType: entry.mealType, foodName: entry.title,
                                    servings: entry.servings, servingDescription: "serving",
                                    calories: entry.totalCalories, protein: entry.totalProtein,
                                    carbs: entry.totalCarbs, fat: entry.totalFat,
                                    foodItemID: entry.foodItemID))
        entry.isLogged = true
        try? context.save()
    }

    private func clearDay() {
        context.deletePlanEntries(dayEntries, undo: undoCenter)
    }

    private func copyToTomorrow() {
        let tomorrow = selectedDay.adding(days: 1)
        for e in dayEntries {
            context.insert(MealPlanEntry(day: tomorrow, mealType: e.mealType, title: e.title, servings: e.servings,
                                         caloriesPerServing: e.caloriesPerServing, proteinPerServing: e.proteinPerServing,
                                         carbsPerServing: e.carbsPerServing, fatPerServing: e.fatPerServing,
                                         recipeID: e.recipeID, foodItemID: e.foodItemID))
        }
        try? context.save()
        selectedDay = tomorrow
    }

    /// Picks, for each meal, the recipe whose calories best match that meal's share of the daily budget.
    /// Recently used recipes on nearby days are avoided so the week has some variety.
    private func autoFill(replace: Bool) {
        if replace { for e in dayEntries { context.delete(e) } }
        let window = allEntries.filter { abs($0.day.timeIntervalSince(selectedDay)) < 3 * 86_400 }
        let recentlyUsed = Set(window.compactMap(\.recipeID))
        for meal in MealType.allCases {
            guard replace || entries(for: meal).isEmpty else { continue }
            let mealTarget = Double(target) * meal.budgetShare
            let candidates = recipes.filter { $0.mealType == meal && $0.caloriesPerServing > 0 }
            guard !candidates.isEmpty else { continue }
            let fresh = candidates.filter { !recentlyUsed.contains($0.uuid) }
            let pool = fresh.isEmpty ? candidates : fresh
            let best = pool.min { abs($0.caloriesPerServing - mealTarget) < abs($1.caloriesPerServing - mealTarget) }
            if let best {
                context.insert(MealPlanEntry(day: selectedDay, mealType: meal, title: best.name,
                                             caloriesPerServing: best.caloriesPerServing,
                                             proteinPerServing: best.proteinPerServing,
                                             carbsPerServing: best.carbsPerServing,
                                             fatPerServing: best.fatPerServing,
                                             recipeID: best.uuid))
            }
        }
        try? context.save()
    }
}

struct PlanEntryRow: View {
    let entry: MealPlanEntry
    var onLog: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var recipes: [Recipe]

    private var recipe: Recipe? {
        guard let id = entry.recipeID else { return nil }
        return recipes.first { $0.uuid == id }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let recipe {
                    NavigationLink(value: recipe) {
                        Text(entry.title)
                    }
                } else {
                    Text(entry.title)
                }
                HStack(spacing: 8) {
                    Text("\(Int(entry.totalCalories.rounded())) kcal")
                    if entry.servings != 1 {
                        Text("× \(entry.servings.cleanString)")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.secondary)
            }
            Spacer()
            if entry.isLogged {
                Label("Logged", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.green)
            } else {
                Button("Log", action: onLog)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                entry.servings = min(entry.servings + 0.5, 10)
                try? context.save()
            } label: { Label("More", systemImage: "plus") }
            .tint(.green)
            Button {
                entry.servings = max(entry.servings - 0.5, 0.5)
                try? context.save()
            } label: { Label("Less", systemImage: "minus") }
            .tint(.orange)
        }
    }
}

// MARK: - Picker for adding recipes or foods to a plan slot

struct PlanItemPicker: View {
    let day: Date
    let mealType: MealType

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]

    @State private var search = ""
    @State private var source: Source = .recipes

    enum Source: String, CaseIterable, Identifiable {
        case recipes = "Recipes"
        case foods = "Foods"
        var id: String { rawValue }
    }

    private var query: String { search.trimmingCharacters(in: .whitespaces).lowercased() }

    /// Recipes for this meal slot first, then everything else.
    private var matchingRecipes: [Recipe] {
        if !query.isEmpty {
            return recipes.filter { $0.name.lowercased().contains(query) }
        }
        let preferred = recipes.filter { $0.mealType == mealType }
        let others = recipes.filter { $0.mealType != mealType }
        return preferred + others
    }

    private var matchingFoods: [FoodItem] {
        query.isEmpty ? foods : foods.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Source", selection: $source) {
                        ForEach(Source.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                switch source {
                case .recipes:
                    Section {
                        ForEach(matchingRecipes) { recipe in
                            Button { add(recipe) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(recipe.name).foregroundStyle(Color.primary)
                                        Text("\(recipe.mealType.label) · \(recipe.prepMinutes) min")
                                            .font(.caption).foregroundStyle(Color.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(recipe.caloriesPerServing.rounded()))")
                                        .font(.body.monospacedDigit()).foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    }
                case .foods:
                    Section {
                        ForEach(matchingFoods) { food in
                            Button { add(food) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(food.displayName).foregroundStyle(Color.primary)
                                        Text(food.servingDescription).font(.caption).foregroundStyle(Color.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(food.calories.rounded()))")
                                        .font(.body.monospacedDigit()).foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Plan \(mealType.label.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func add(_ recipe: Recipe) {
        context.insert(MealPlanEntry(day: day, mealType: mealType, title: recipe.name,
                                     caloriesPerServing: recipe.caloriesPerServing,
                                     proteinPerServing: recipe.proteinPerServing,
                                     carbsPerServing: recipe.carbsPerServing,
                                     fatPerServing: recipe.fatPerServing,
                                     recipeID: recipe.uuid))
        try? context.save()
        dismiss()
    }

    private func add(_ food: FoodItem) {
        context.insert(MealPlanEntry(day: day, mealType: mealType, title: food.displayName,
                                     caloriesPerServing: food.calories,
                                     proteinPerServing: food.protein,
                                     carbsPerServing: food.carbs,
                                     fatPerServing: food.fat,
                                     foodItemID: food.uuid))
        try? context.save()
        dismiss()
    }
}

// MARK: - Grocery list

struct GroceryListView: View {
    @Query(sort: \MealPlanEntry.day) private var entries: [MealPlanEntry]
    @Query private var recipes: [Recipe]
    @AppStorage("groceryChecked") private var checkedData: Data = Data()

    @State private var weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? Date.now.startOfDay

    private var weekEnd: Date { weekStart.adding(days: 7) }

    private struct Item: Identifiable {
        var id: String { name }
        let name: String
        let amounts: [String]
        let usedIn: Set<String>
    }

    private var checked: Set<String> {
        (try? JSONDecoder().decode(Set<String>.self, from: checkedData)) ?? []
    }

    private func setChecked(_ set: Set<String>) {
        checkedData = (try? JSONEncoder().encode(set)) ?? Data()
    }

    private var items: [Item] {
        let weekEntries = entries.filter { $0.day >= weekStart && $0.day < weekEnd }
        var amounts: [String: [(amount: String, multiplier: Double)]] = [:]
        var usedIn: [String: Set<String>] = [:]
        var order: [String] = []
        for entry in weekEntries {
            if let id = entry.recipeID, let recipe = recipes.first(where: { $0.uuid == id }) {
                let multiplier = entry.servings / Double(max(recipe.servings, 1))
                for ing in recipe.ingredients {
                    let key = ing.name.lowercased()
                    if amounts[key] == nil { order.append(key) }
                    amounts[key, default: []].append((ing.amount, multiplier))
                    usedIn[key, default: []].insert(recipe.name)
                }
            } else {
                let key = entry.title.lowercased()
                if amounts[key] == nil { order.append(key) }
                amounts[key, default: []].append(("\(entry.servings.cleanString) serving", 1))
                usedIn[key, default: []].insert("Planned as a food")
            }
        }
        return order.map {
            Item(name: $0, amounts: GroceryAggregator.combine(amounts[$0] ?? []), usedIn: usedIn[$0] ?? [])
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Button { weekStart = weekStart.adding(days: -7) } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text("\(weekStart.formatted(.dateTime.month(.abbreviated).day())) – \(weekEnd.adding(days: -1).formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.headline)
                    Spacer()
                    Button { weekStart = weekStart.adding(days: 7) } label: { Image(systemName: "chevron.right") }
                }
                .buttonStyle(.bordered)
            }
            if items.isEmpty {
                ContentUnavailableView("Nothing planned this week", systemImage: "cart",
                                       description: Text("Add recipes to the planner and their ingredients will show up here."))
            } else {
                Section {
                    ForEach(items) { item in
                        let isChecked = checked.contains(item.name)
                        Button {
                            var set = checked
                            if isChecked { set.remove(item.name) } else { set.insert(item.name) }
                            setChecked(set)
                        } label: {
                            HStack(alignment: .top) {
                                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isChecked ? Color.green : Color.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name.capitalized)
                                        .strikethrough(isChecked)
                                        .foregroundStyle(isChecked ? Color.secondary : Color.primary)
                                    Text(item.amounts.joined(separator: " + "))
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                    Text(item.usedIn.sorted().joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("\(items.count) items")
                        Spacer()
                        Button("Uncheck all") { setChecked([]) }
                            .font(.caption)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
