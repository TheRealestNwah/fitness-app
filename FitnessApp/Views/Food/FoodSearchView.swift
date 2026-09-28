import PhotosUI
import SwiftUI
import SwiftData
import TipKit

/// Searchable list of foods that logs a chosen item to a given meal on a given date.
struct FoodSearchView: View {
    let date: Date
    @State var mealType: MealType

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]

    @State private var search = ""
    @AppStorage(RecentSearches.storageKey) private var recentSearches = ""
    @State private var loggedMealName: String?
    @State private var selected: FoodItem?
    @State private var selectedRecipe: Recipe?
    @State private var showCreate = false
    @State private var showQuickAdd = false
    @State private var showSentence = false
    @State private var showScanner = false
    @State private var unknownBarcode: UnknownBarcode?

    init(date: Date, mealType: MealType) {
        self.date = date
        _mealType = State(initialValue: mealType)
    }

    private var query: String { search.trimmingCharacters(in: .whitespaces).lowercased() }

    /// Best match first; favourites and recently used foods outrank generic ones.
    private var filtered: [FoodItem] {
        guard !query.isEmpty else { return foods }
        return FoodSearchRanking.rank(foods, query: query) {
            .init(name: $0.name, other: [$0.brand, $0.barcode ?? ""], isFavorite: $0.isFavorite, lastUsed: $0.lastUsed)
        }
    }

    private var filteredRecipes: [Recipe] {
        guard !query.isEmpty else { return [] }
        return FoodSearchRanking.rank(recipes, query: query) { .init(name: $0.name, isFavorite: $0.isFavorite) }
    }

    private var recent: [FoodItem] {
        foods.filter { $0.lastUsed != nil }
            .sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
            .prefix(8)
            .map { $0 }
    }

    private var favorites: [FoodItem] { foods.filter(\.isFavorite) }

    /// Favourite meals for this slot first, then the rest. When searching, ranked by name, then by
    /// slot ("lunch") or the foods in them.
    private var matchingSavedMeals: [SavedMeal] {
        let bySlot = savedMeals.sorted { a, b in
            if (a.mealType == mealType) != (b.mealType == mealType) { return a.mealType == mealType }
            return a.name < b.name
        }
        guard !query.isEmpty else { return bySlot }
        return FoodSearchRanking.rank(bySlot, query: query) {
            .init(name: $0.name, other: [$0.mealType.label] + $0.items.map(\.foodName), isFavorite: true)
        }
    }

    private func logSavedMeal(_ meal: SavedMeal) {
        meal.log(on: date, as: mealType, context: context)
        try? context.save()
        withAnimation { loggedMealName = meal.name }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }

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
                if let loggedMealName {
                    Section {
                        Label("Logged “\(loggedMealName)” to \(mealType.inSentence)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                    }
                }
                if !matchingSavedMeals.isEmpty {
                    Section("Favourite meals") {
                        ForEach(matchingSavedMeals) { meal in
                            Button { logSavedMeal(meal) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(meal.name).foregroundStyle(Color.primary)
                                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                                        }
                                        Text(meal.summary)
                                            .font(.caption)
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(Int(meal.totalCalories.rounded()))")
                                            .font(.body.monospacedDigit())
                                        Text("\(meal.items.count) items")
                                            .font(.caption2)
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(meal)
                                    try? context.save()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
                if query.isEmpty, !RecentSearches.list(recentSearches).isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(RecentSearches.list(recentSearches), id: \.self) { term in
                                    Button(term) { search = term }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Recent searches")
                            Spacer()
                            Button("Clear") { recentSearches = "" }
                                .font(.caption)
                                .textCase(nil)
                        }
                    }
                }
                if query.isEmpty {
                    Section {
                        TipView(BarcodeTip())
                        Button {
                            BarcodeTip().invalidate(reason: .actionPerformed)
                            showScanner = true
                        } label: {
                            Label("Scan a barcode", systemImage: "barcode.viewfinder")
                        }
                        Button { showSentence = true } label: {
                            Label("Describe what you ate", systemImage: "text.bubble")
                        }
                        .accessibilityIdentifier("describeMeal")
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
                                        Text(recipe.name).foregroundStyle(Color.primary)
                                        Text("1 serving").font(.caption).foregroundStyle(Color.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(recipe.caloriesPerServing.rounded()))")
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    }
                }
                Section(query.isEmpty ? "All foods" : "Results") {
                    if filtered.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No match for “\(search)”.")
                                .foregroundStyle(Color.secondary)
                            Button("Create “\(search)” as a custom food") { showCreate = true }
                        }
                    }
                    ForEach(filtered) { food in foodRow(food) }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods")
            .onSubmit(of: .search) { rememberSearch() }
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
            .sheet(isPresented: $showScanner) {
                BarcodeScanSheet(onFound: { food in
                    showScanner = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { selected = food }
                }, onNotFound: { code in
                    showScanner = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { unknownBarcode = UnknownBarcode(code: code) }
                })
            }
            .sheet(item: $unknownBarcode) { unknown in
                CreateFoodSheet(initialName: "", barcode: unknown.code) { created in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { selected = created }
                }
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddSheet(date: date, mealType: mealType)
            }
            .sheet(isPresented: $showSentence) {
                SentenceLogSheet(date: date, mealType: mealType) {
                    // Everything's logged: close search too once the sheet has gone.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dismiss() }
                }
            }
        }
    }

    private func rememberSearch() {
        if !query.isEmpty { recentSearches = RecentSearches.adding(search, to: recentSearches) }
    }

    private func foodRow(_ food: FoodItem) -> some View {
        Button { rememberSearch(); selected = food } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(food.displayName).foregroundStyle(Color.primary)
                        if food.isFavorite {
                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                        }
                    }
                    Text(food.servingDescription).font(.caption).foregroundStyle(Color.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(food.calories.rounded()))")
                        .font(.body.monospacedDigit())
                    Text("P\(Int(food.protein)) C\(Int(food.carbs)) F\(Int(food.fat))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.secondary)
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
                    ServingsControl(servings: $servings, description: food.servingDescription,
                                    metric: ServingUnits.metricPerServing(food.servingDescription),
                                    presets: food.servingPresets)
                }
                Section("This entry") {
                    LabeledContent("Calories", value: "\(Energy.string((food.calories * servings)))")
                    LabeledContent("Protein", value: "\(Int((food.protein * servings).rounded())) g")
                    LabeledContent("Carbs", value: "\(Int((food.carbs * servings).rounded())) g")
                    LabeledContent("Fat", value: "\(Int((food.fat * servings).rounded())) g")
                    if food.fiber > 0 {
                        LabeledContent("Fibre", value: "\(Int((food.fiber * servings).rounded())) g")
                    }
                }
            }
            .navigationTitle("Add to \(meal.inSentence)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { log() }.disabled(servings <= 0)
                }
            }
            .onAppear {
                meal = mealType
                servings = food.lastServings ?? 1
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func log() {
        food.log(servings: servings, meal: meal, on: date, context: context)
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
                    LabeledContent("Calories", value: "\(Energy.string((recipe.caloriesPerServing * servings)))")
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
                        context.insertDiaryEntry(FoodLogEntry(date: meal.logDate(on: date), mealType: meal, foodName: recipe.name,
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
                        context.insertDiaryEntry(FoodLogEntry(date: meal.logDate(on: date), mealType: meal,
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
    var barcode: String? = nil
    var onCreate: ((FoodItem) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var brand = ""
    @State private var serving = "1 serving"
    @State private var measureName = ""
    @State private var measureServings: Double?
    @State private var calories: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var fiber: Double?
    @State private var sugar: Double?
    @State private var sodium: Double?
    @State private var per100g = false
    @State private var servingGrams: Double?
    @State private var showCamera = false
    @State private var labelPhoto: PhotosPickerItem?
    @State private var scanning = false
    @State private var scanNote: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showCamera = true } label: {
                            Label("Photograph the nutrition label", systemImage: "text.viewfinder")
                        }
                    }
                    PhotosPicker(selection: $labelPhoto, matching: .images) {
                        Label("Choose a label photo", systemImage: "photo.on.rectangle")
                    }
                    if scanning { ProgressView("Reading the label…") }
                } header: {
                    Text("Fill from the label")
                } footer: {
                    Text(scanNote ?? "Read on your iPhone; the photo isn't kept.")
                }
                Section {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    TextField("Serving size (e.g. 1 cup, 100 g)", text: $serving)
                } header: {
                    Text("Food")
                } footer: {
                    if let barcode {
                        Text("Barcode \(barcode) wasn't in the database. Copy the numbers from the label and this food will be found instantly next time you scan it.")
                    }
                }
                Section {
                    TextField("Name (e.g. 1 slice, 1 cup)", text: $measureName)
                    DecimalField(title: "Servings in it", value: $measureServings)
                } header: {
                    Text("Household measure (optional)")
                } footer: {
                    Text("Offered as a quick pick when you log this food.")
                }
                Section {
                    Toggle("Label gives values per 100 g", isOn: $per100g)
                    if per100g {
                        DecimalField(title: "One serving weighs", value: $servingGrams, unit: "g")
                    }
                } footer: {
                    if per100g {
                        Text("Enter the label's per-100 g numbers below; they're scaled to one serving when you save.")
                    }
                }
                Section(per100g ? "Nutrition per 100 g" : "Nutrition per serving") {
                    DecimalField(title: "Calories", value: $calories, unit: "kcal")
                    DecimalField(title: "Protein", value: $protein, unit: "g")
                    DecimalField(title: "Carbs", value: $carbs, unit: "g")
                    DecimalField(title: "Fat", value: $fat, unit: "g")
                    DecimalField(title: "Fibre", value: $fiber, unit: "g")
                    DecimalField(title: "Sugar", value: $sugar, unit: "g")
                    DecimalField(title: "Sodium", value: $sodium, unit: "mg")
                }
            }
            .navigationTitle("New food")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in readLabel(image) }.ignoresSafeArea()
            }
            .onChange(of: labelPhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        readLabel(image)
                    }
                    labelPhoto = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let grams = servingGrams ?? 0
                        func n(_ value: Double?) -> Double {
                            per100g ? ServingUnits.perServing(fromPer100: value ?? 0, servingGrams: grams) : value ?? 0
                        }
                        let description = per100g && ServingUnits.metricPerServing(serving) == nil
                            ? "\(grams.cleanString) g" : serving
                        let item = FoodItem(name: name.trimmingCharacters(in: .whitespaces),
                                            brand: brand.trimmingCharacters(in: .whitespaces),
                                            servingDescription: description,
                                            calories: n(calories), protein: n(protein),
                                            carbs: n(carbs), fat: n(fat), fiber: n(fiber),
                                            sugar: n(sugar), sodium: n(sodium),
                                            isCustom: true)
                        item.barcode = barcode
                        let label = measureName.trimmingCharacters(in: .whitespaces)
                        if !label.isEmpty, let amount = measureServings, amount > 0 {
                            item.servingPresets = [ServingPreset(label: label, servings: amount)]
                        }
                        context.insert(item)
                        try? context.save()
                        dismiss()
                        onCreate?(item)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (calories ?? 0) <= 0
                              || (per100g && (servingGrams ?? 0) <= 0))
                }
            }
            .onAppear { if name.isEmpty { name = initialName } }
            .onChange(of: per100g) { _, on in
                if on, servingGrams == nil { servingGrams = ServingUnits.metricPerServing(serving)?.value }
            }
        }
    }

    private func readLabel(_ image: UIImage) {
        scanning = true
        Task { @MainActor in
            let label = NutritionLabelParser.parse(await LabelTextRecognizer.lines(in: image))
            scanning = false
            guard !label.isEmpty else {
                scanNote = "Couldn't read that label. Try a straight-on photo in good light, or type the numbers."
                return
            }
            per100g = label.per100g
            if let grams = label.servingGrams { servingGrams = grams }
            if let description = label.servingDescription, serving == "1 serving" { serving = description }
            calories = label.calories ?? calories
            protein = label.protein ?? protein
            carbs = label.carbs ?? carbs
            fat = label.fat ?? fat
            fiber = label.fiber ?? fiber
            sugar = label.sugar ?? sugar
            sodium = label.sodiumMg ?? sodium
            scanNote = "Filled from the label. Check the numbers before saving."
        }
    }
}
