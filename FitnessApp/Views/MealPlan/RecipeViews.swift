import SwiftUI
import SwiftData

struct RecipeLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.name) private var recipes: [Recipe]

    @State private var search = ""
    @State private var filter: MealType?
    @State private var showEditor = false
    @State private var showImport = false

    private var filtered: [Recipe] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return recipes.filter { recipe in
            (filter == nil || recipe.mealType == filter) &&
            (q.isEmpty || recipe.name.lowercased().contains(q) || recipe.tags.contains { $0.lowercased().contains(q) })
        }
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isOn: filter == nil) { filter = nil }
                        ForEach(MealType.allCases) { meal in
                            FilterChip(title: meal.label, isOn: filter == meal) { filter = meal }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
            }
            Section {
                ForEach(filtered) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeRow(recipe: recipe)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            recipe.isFavorite.toggle()
                            try? context.save()
                        } label: { Label("Favourite", systemImage: recipe.isFavorite ? "star.slash" : "star") }
                        .tint(.yellow)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            context.delete(recipe)
                            try? context.save()
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            } header: {
                HStack {
                    Text("\(filtered.count) recipes")
                    Spacer()
                    Menu {
                        Button { showEditor = true } label: { Label("New recipe", systemImage: "square.and.pencil") }
                        Button { showImport = true } label: { Label("Import from a web page", systemImage: "link") }
                    } label: {
                        Label("Add recipe", systemImage: "plus")
                    }
                    .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, prompt: "Search recipes or tags")
        .sheet(isPresented: $showEditor) { RecipeEditorView() }
        .sheet(isPresented: $showImport) { ImportRecipeSheet() }
    }
}

struct FilterChip: View {
    var title: String
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isOn ? Color.accentColor : Color(.tertiarySystemFill), in: Capsule())
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recipe.mealType.systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(recipe.name)
                    if recipe.isFavorite {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                    }
                }
                HStack(spacing: 6) {
                    Text("\(Energy.string(recipe.caloriesPerServing))")
                    Text("·")
                    Text("\(Int(recipe.proteinPerServing.rounded()))g protein")
                    Text("·")
                    Text("\(recipe.prepMinutes) min")
                }
                .font(.caption)
                .foregroundStyle(Color.secondary)
            }
        }
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var context
    @State private var showPlan = false
    @State private var showLog = false
    @State private var showEditor = false
    @State private var scaledServings = 0

    private var servingsShown: Int { scaledServings > 0 ? scaledServings : recipe.servings }
    private var factor: Double { Double(servingsShown) / Double(max(recipe.servings, 1)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    StatTile(title: "Calories", value: "\(Int(recipe.caloriesPerServing.rounded()))", subtitle: "per serving", systemImage: "flame.fill", tint: .orange)
                    StatTile(title: "Protein", value: "\(Int(recipe.proteinPerServing.rounded())) g", subtitle: "carbs \(Int(recipe.carbsPerServing.rounded())) · fat \(Int(recipe.fatPerServing.rounded()))", systemImage: "p.circle.fill", tint: .blue)
                }
                HStack {
                    Label("\(recipe.servings) servings", systemImage: "person.2")
                    Spacer()
                    Label("\(recipe.prepMinutes) min", systemImage: "clock")
                    Spacer()
                    Label(recipe.mealType.label, systemImage: recipe.mealType.systemImage)
                }
                .font(.subheadline)
                .foregroundStyle(Color.secondary)

                if !recipe.tags.isEmpty {
                    HStack {
                        ForEach(recipe.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button { showLog = true } label: {
                        Label("Log now", systemImage: "fork.knife")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button { showPlan = true } label: {
                        Label("Add to plan", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Ingredients").font(.headline)
                        Spacer()
                        Stepper(value: Binding(get: { servingsShown }, set: { scaledServings = $0 }), in: 1...40) {
                            Text("for \(servingsShown)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(servingsShown == recipe.servings ? Color.secondary : Color.accentColor)
                        }
                        .fixedSize()
                        .accessibilityLabel("Servings to cook")
                    }
                    ForEach(recipe.ingredients) { ing in
                        HStack(alignment: .top) {
                            Text("•")
                            Text(ing.name)
                            Spacer()
                            Text(RecipeScaler.scale(ing.amount, by: factor)).foregroundStyle(Color.secondary)
                        }
                        .font(.subheadline)
                    }
                    if servingsShown != recipe.servings {
                        Text("Scaled from \(recipe.servings) servings. Nutrition per serving is unchanged.")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                if !recipe.instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Method").font(.headline)
                        Text(recipe.instructions)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEditor = true } label: { Label("Edit recipe", systemImage: "pencil") }
                    Button {
                        recipe.isFavorite.toggle()
                        try? context.save()
                    } label: {
                        Label(recipe.isFavorite ? "Remove favourite" : "Favourite", systemImage: recipe.isFavorite ? "star.slash" : "star")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showLog) {
            LogRecipeSheet(recipe: recipe, date: .now, mealType: recipe.mealType)
        }
        .sheet(isPresented: $showPlan) {
            AddToPlanSheet(recipe: recipe)
        }
        .sheet(isPresented: $showEditor) {
            RecipeEditorView(recipe: recipe)
        }
    }
}

struct AddToPlanSheet: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var day = Date.now
    @State private var meal: MealType = .dinner
    @State private var servings: Double = 1

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Day", selection: $day, displayedComponents: .date)
                Picker("Meal", selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.label).tag($0) }
                }
                ServingsControl(servings: $servings, description: "1 serving of recipe")
            }
            .navigationTitle("Add to plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        context.insert(MealPlanEntry(day: day, mealType: meal, title: recipe.name, servings: servings,
                                                     caloriesPerServing: recipe.caloriesPerServing,
                                                     proteinPerServing: recipe.proteinPerServing,
                                                     carbsPerServing: recipe.carbsPerServing,
                                                     fatPerServing: recipe.fatPerServing,
                                                     recipeID: recipe.uuid))
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .onAppear { meal = recipe.mealType }
        }
        .presentationDetents([.medium])
    }
}

struct RecipeEditorView: View {
    var recipe: Recipe?
    /// Pre-fills a new recipe from a web page.
    var imported: RecipeImporter.Imported? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var mealType: MealType = .dinner
    @State private var servings = 1
    @State private var prepMinutes = 15
    @State private var ingredients: [Ingredient] = []
    @State private var instructions = ""
    @State private var tagsText = ""
    @State private var loaded = false
    @State private var showIngredientSheet = false

    private var totalCalories: Double { ingredients.reduce(0) { $0 + $1.calories } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $name)
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("Servings: \(servings)", value: $servings, in: 1...20)
                    Stepper("Prep time: \(prepMinutes) min", value: $prepMinutes, in: 0...240, step: 5)
                    TextField("Tags, comma separated", text: $tagsText)
                }
                Section {
                    ForEach(ingredients) { ing in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ing.name)
                                Text(ing.amount).font(.caption).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Text("\(Energy.string(ing.calories))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }
                    Button { showIngredientSheet = true } label: {
                        Label("Add ingredient", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Ingredients")
                } footer: {
                    if servings > 0, !ingredients.isEmpty {
                        Text("\(Energy.string(totalCalories)) total · \(Energy.string(totalCalories / Double(servings))) per serving")
                    }
                }
                Section("Method") {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(recipe == nil ? "New recipe" : "Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || ingredients.isEmpty)
                }
            }
            .sheet(isPresented: $showIngredientSheet) {
                IngredientEditor { ingredients.append($0) }
            }
            .onAppear {
                guard !loaded else { return }
                if recipe == nil, let imported {
                    loaded = true
                    load(imported)
                    return
                }
                guard let recipe else { return }
                loaded = true
                name = recipe.name
                mealType = recipe.mealType
                servings = recipe.servings
                prepMinutes = recipe.prepMinutes
                ingredients = recipe.ingredients
                instructions = recipe.instructions
                tagsText = recipe.tags.joined(separator: ", ")
            }
        }
    }

    private func load(_ page: RecipeImporter.Imported) {
        name = page.name
        servings = min(max(page.servings, 1), 20)
        prepMinutes = min(page.prepMinutes, 240)
        instructions = page.instructions
        // Lines arrive without nutrition. If the page lists nutrition, keep it as one line.
        ingredients = page.ingredients.map { Ingredient(name: $0, amount: "", calories: 0, protein: 0, carbs: 0, fat: 0) }
        if let kcal = page.calories {
            let n = Double(servings)
            ingredients.append(Ingredient(name: "Nutrition from the recipe page", amount: "\(servings) servings",
                                          calories: kcal * n, protein: (page.protein ?? 0) * n,
                                          carbs: (page.carbs ?? 0) * n, fat: (page.fat ?? 0) * n))
        }
    }

    private func save() {
        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let recipe {
            recipe.name = name.trimmingCharacters(in: .whitespaces)
            recipe.mealType = mealType
            recipe.servings = servings
            recipe.prepMinutes = prepMinutes
            recipe.ingredients = ingredients
            recipe.instructions = instructions
            recipe.tags = tags
        } else {
            context.insert(Recipe(name: name.trimmingCharacters(in: .whitespaces), mealType: mealType, servings: servings,
                                  prepMinutes: prepMinutes, ingredients: ingredients, instructions: instructions,
                                  tags: tags, isCustom: true))
        }
        try? context.save()
        dismiss()
    }
}

struct IngredientEditor: View {
    var onAdd: (Ingredient) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]

    @State private var name = ""
    @State private var amount = ""
    @State private var calories: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var search = ""
    @State private var picked: FoodItem?
    @State private var quantity: Double = 1

    private var suggestions: [FoodItem] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        return Array(foods.filter { $0.name.lowercased().contains(q) }.prefix(6))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Search the food list to autofill", text: $search)
                    ForEach(suggestions) { food in
                        Button {
                            name = food.name
                            picked = food
                            quantity = 1
                            apply(food)
                            search = ""
                        } label: {
                            HStack {
                                Text(food.name).foregroundStyle(Color.primary)
                                Spacer()
                                Text("\(Energy.string(food.calories))").foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }
                if let picked {
                    Section("How much \(picked.name)") {
                        ServingsControl(servings: $quantity, description: picked.servingDescription,
                                        metric: ServingUnits.metricPerServing(picked.servingDescription),
                                        presets: picked.servingPresets)
                    }
                    .onChange(of: quantity) { _, _ in apply(picked) }
                }
                Section("Ingredient") {
                    TextField("Name", text: $name)
                    TextField("Amount (e.g. 200 g, 1 cup)", text: $amount)
                }
                Section("Nutrition for this amount") {
                    DecimalField(title: "Calories", value: $calories, unit: "kcal")
                    DecimalField(title: "Protein", value: $protein, unit: "g")
                    DecimalField(title: "Carbs", value: $carbs, unit: "g")
                    DecimalField(title: "Fat", value: $fat, unit: "g")
                }
            }
            .navigationTitle("Add ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(Ingredient(name: name.trimmingCharacters(in: .whitespaces), amount: amount,
                                         calories: calories ?? 0, protein: protein ?? 0, carbs: carbs ?? 0, fat: fat ?? 0))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

extension IngredientEditor {
    /// Nutrition and amount for `quantity` servings of a food from the list.
    fileprivate func apply(_ food: FoodItem) {
        calories = food.calories * quantity
        protein = food.protein * quantity
        carbs = food.carbs * quantity
        fat = food.fat * quantity
        if let metric = ServingUnits.metricPerServing(food.servingDescription) {
            amount = "\(RecipeScaler.formatMetric(metric.value * quantity)) \(metric.unit)"
        } else {
            amount = quantity == 1 ? food.servingDescription
                : "\(RecipeScaler.formatQuantity(quantity)) × \(food.servingDescription)"
        }
    }
}

/// Paste a recipe page's address; the recipe opens in the editor to check before saving.
struct ImportRecipeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var loading = false
    @State private var error: String?
    @State private var imported: RecipeImporter.Imported?

    var body: some View {
        if let imported {
            RecipeEditorView(imported: imported)
        } else {
            NavigationStack {
                Form {
                    Section {
                        TextField("https://", text: $address)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } footer: {
                        Text("Works with most recipe sites. Ingredients come in without nutrition unless the page lists it; edit them in the recipe to add it from your food list.")
                    }
                    if let error {
                        Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                    }
                    if loading {
                        Section { ProgressView("Reading the page") }
                    }
                }
                .navigationTitle("Import recipe")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") { load() }
                            .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || loading)
                    }
                }
            }
        }
    }

    private func load() {
        loading = true
        error = nil
        Task { @MainActor in
            defer { loading = false }
            do {
                imported = try await RecipeImporter.fetch(address)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
