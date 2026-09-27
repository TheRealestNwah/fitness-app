import SwiftUI
import SwiftData

/// Searchable list of foods that logs a chosen item to a given meal on a given date.
struct FoodSearchView: View {
    let date: Date
    @State var mealType: MealType

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @Query(sort: \Recipe.name) private var recipes: [Recipe]

    @State private var search = ""
    @State private var selected: FoodItem?
    @State private var selectedRecipe: Recipe?
    @State private var showCreate = false
    @State private var showQuickAdd = false

    init(date: Date, mealType: MealType) {
        self.date = date
        _mealType = State(initialValue: mealType)
    }

    private var query: String { search.trimmingCharacters(in: .whitespaces).lowercased() }

    private var filtered: [FoodItem] {
        guard !query.isEmpty else { return foods }
        return foods.filter { $0.name.lowercased().contains(query) || $0.brand.lowercased().contains(query) }
    }

    private var filteredRecipes: [Recipe] {
        guard !query.isEmpty else { return [] }
        return recipes.filter { $0.name.lowercased().contains(query) }
    }

    private var recent: [FoodItem] {
        foods.filter { $0.lastUsed != nil }
            .sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
            .prefix(8)
            .map { $0 }
    }

    private var favorites: [FoodItem] { foods.filter(\.isFavorite) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if query.isEmpty {
                    Section {
                        Button { showQuickAdd = true } label: {
                            Label("Quick add calories", systemImage: "bolt.fill")
                        }
                        Button { showCreate = true } label: {
                            Label("Create a custom food", systemImage: "plus.circle")
                        }
                    }
                    if !recent.isEmpty {
                        Section("Recent") {
                            ForEach(recent) { food in foodRow(food) }
                        }
                    }
                    if !favorites.isEmpty {
                        Section("Favourites") {
                            ForEach(favorites) { food in foodRow(food) }
                        }
                    }
                }
                if !filteredRecipes.isEmpty {
                    Section("Recipes") {
                        ForEach(filteredRecipes) { recipe in
                            Button { selectedRecipe = recipe } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(recipe.name).foregroundStyle(.primary)
                                        Text("1 serving").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(recipe.caloriesPerServing.rounded()))")
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section(query.isEmpty ? "All foods" : "Results") {
                    if filtered.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No match for “\(search)”.")
                                .foregroundStyle(.secondary)
                            Button("Create “\(search)” as a custom food") { showCreate = true }
                        }
                    }
                    ForEach(filtered) { food in foodRow(food) }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods")
            .navigationTitle("Log food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $selected) { food in
                LogFoodSheet(food: food, date: date, mealType: mealType)
            }
            .sheet(item: $selectedRecipe) { recipe in
                LogRecipeSheet(recipe: recipe, date: date, mealType: mealType)
            }
            .sheet(isPresented: $showCreate) {
                CreateFoodSheet(initialName: query.isEmpty ? "" : search) { created in
                    // Wait for the create sheet to finish dismissing before presenting the log sheet.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        selected = created
                    }
                }
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddSheet(date: date, mealType: mealType)
            }
        }
    }

    private func foodRow(_ food: FoodItem) -> some View {
        Button { selected = food } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(food.displayName).foregroundStyle(.primary)
                        if food.isFavorite {
                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                        }
                    }
                    Text(food.servingDescription).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(food.calories.rounded()))")
                        .font(.body.monospacedDigit())
                    Text("P\(Int(food.protein)) C\(Int(food.carbs)) F\(Int(food.fat))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                food.isFavorite.toggle()
                try? context.save()
            } label: {
                Label(food.isFavorite ? "Unfavourite" : "Favourite", systemImage: food.isFavorite ? "star.slash" : "star")
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing) {
            if food.isCustom {
                Button(role: .destructive) {
                    context.delete(food)
                    try? context.save()
                } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }
}

struct LogFoodSheet: View {
    let food: FoodItem
    let date: Date
    let mealType: MealType

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var servings: Double = 1
    @State private var meal: MealType = .snack

    var body: some View {
        NavigationStack {
            Form {
                Section(food.displayName) {
                    Picker("Meal", selection: $meal) {
                        ForEach(MealType.allCases) { Text($0.label).tag($0) }
                    }
                    ServingsControl(servings: $servings, description: food.servingDescription)
                }
                Section("This entry") {
                    LabeledContent("Calories", value: "\(Int((food.calories * servings).rounded())) kcal")
                    LabeledContent("Protein", value: "\(Int((food.protein * servings).rounded())) g")
                    LabeledContent("Carbs", value: "\(Int((food.carbs * servings).rounded())) g")
                    LabeledContent("Fat", value: "\(Int((food.fat * servings).rounded())) g")
                    if food.fiber > 0 {
                        LabeledContent("Fibre", value: "\(Int((food.fiber * servings).rounded())) g")
                    }
                }
            }
            .navigationTitle("Add to \(meal.label.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { log() }.disabled(servings <= 0)
                }
            }
            .onAppear { meal = mealType }
        }
        .presentationDetents([.medium, .large])
    }

    private func log() {
        let entry = FoodLogEntry(date: date,
                                 mealType: meal,
                                 foodName: food.displayName,
                                 servings: servings,
                                 servingDescription: food.servingDescription,
                                 calories: food.calories * servings,
                                 protein: food.protein * servings,
                                 carbs: food.carbs * servings,
                                 fat: food.fat * servings,
                                 foodItemID: food.uuid)
        context.insert(entry)
        food.lastUsed = .now
        food.useCount += 1
        try? context.save()
        dismiss()
    }
}

struct LogRecipeSheet: View {
    let recipe: Recipe
    let date: Date
    let mealType: MealType

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var servings: Double = 1
    @State private var meal: MealType = .snack

    var body: some View {
        NavigationStack {
            Form {
                Section(recipe.name) {
                    Picker("Meal", selection: $meal) {
                        ForEach(MealType.allCases) { Text($0.label).tag($0) }
                    }
                    ServingsControl(servings: $servings, description: "1 serving of recipe")
                }
                Section("This entry") {
                    LabeledContent("Calories", value: "\(Int((recipe.caloriesPerServing * servings).rounded())) kcal")
                    MacroSummary(protein: recipe.proteinPerServing * servings,
                                 carbs: recipe.carbsPerServing * servings,
                                 fat: recipe.fatPerServing * servings)
                }
            }
            .navigationTitle("Log recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        context.insert(FoodLogEntry(date: date, mealType: meal, foodName: recipe.name,
                                                    servings: servings, servingDescription: "serving",
                                                    calories: recipe.caloriesPerServing * servings,
                                                    protein: recipe.proteinPerServing * servings,
                                                    carbs: recipe.carbsPerServing * servings,
                                                    fat: recipe.fatPerServing * servings))
                        try? context.save()
                        dismiss()
                    }
                    .disabled(servings <= 0)
                }
            }
            .onAppear { meal = mealType }
        }
        .presentationDetents([.medium])
    }
}

struct QuickAddSheet: View {
    let date: Date
    let mealType: MealType

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var calories: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var meal: MealType = .snack

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Description (e.g. Restaurant pasta)", text: $name)
                    Picker("Meal", selection: $meal) {
                        ForEach(MealType.allCases) { Text($0.label).tag($0) }
                    }
                    DecimalField(title: "Calories", value: $calories, unit: "kcal")
                } footer: {
                    Text("Use this for meals you can't look up. Macros are optional.")
                }
                Section("Macros (optional)") {
                    DecimalField(title: "Protein", value: $protein, unit: "g")
                    DecimalField(title: "Carbs", value: $carbs, unit: "g")
                    DecimalField(title: "Fat", value: $fat, unit: "g")
                }
            }
            .navigationTitle("Quick add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        context.insert(FoodLogEntry(date: date, mealType: meal,
                                                    foodName: name.isEmpty ? "Quick add" : name,
                                                    servings: 1, servingDescription: "",
                                                    calories: calories ?? 0, protein: protein ?? 0,
                                                    carbs: carbs ?? 0, fat: fat ?? 0))
                        try? context.save()
                        dismiss()
                    }
                    .disabled((calories ?? 0) <= 0)
                }
            }
            .onAppear { meal = mealType }
        }
        .presentationDetents([.medium, .large])
    }
}

struct CreateFoodSheet: View {
    var initialName: String = ""
    var onCreate: ((FoodItem) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var brand = ""
    @State private var serving = "1 serving"
    @State private var calories: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var fiber: Double?

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    TextField("Serving size (e.g. 1 cup, 100 g)", text: $serving)
                }
                Section("Nutrition per serving") {
                    DecimalField(title: "Calories", value: $calories, unit: "kcal")
                    DecimalField(title: "Protein", value: $protein, unit: "g")
                    DecimalField(title: "Carbs", value: $carbs, unit: "g")
                    DecimalField(title: "Fat", value: $fat, unit: "g")
                    DecimalField(title: "Fibre", value: $fiber, unit: "g")
                }
            }
            .navigationTitle("New food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let item = FoodItem(name: name.trimmingCharacters(in: .whitespaces),
                                            brand: brand.trimmingCharacters(in: .whitespaces),
                                            servingDescription: serving,
                                            calories: calories ?? 0, protein: protein ?? 0,
                                            carbs: carbs ?? 0, fat: fat ?? 0, fiber: fiber ?? 0,
                                            isCustom: true)
                        context.insert(item)
                        try? context.save()
                        dismiss()
                        onCreate?(item)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (calories ?? 0) <= 0)
                }
            }
            .onAppear { if name.isEmpty { name = initialName } }
        }
    }
}
