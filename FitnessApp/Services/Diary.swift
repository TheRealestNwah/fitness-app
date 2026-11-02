import Foundation
import SwiftData

/// The food-entry lifecycle in one place: logging from a food, recipe, saved meal, meal-prep batch
/// or plan item, quick add, logging again, copying, moving, changing and deleting diary entries.
///
/// Every path builds the full snapshot (ADR 0004), other nutrients included, mirrors it to Apple
/// Health, saves, and when given an undo center offers to undo. Foods remember the amount logged,
/// so the next log of the same food starts from it wherever it happens.
///
/// Pass `undo: nil` from a sheet that stays open (the toast would sit behind it).
@MainActor
struct Diary {
    let context: ModelContext
    var undo: UndoCenter?

    init(_ context: ModelContext, undo: UndoCenter? = nil) {
        self.context = context
        self.undo = undo
    }

    // MARK: Logging

    /// Logs a food. Without `servings`, uses the amount last logged (or one serving).
    @discardableResult
    func log(_ food: FoodItem, servings: Double? = nil, as meal: MealType, on day: Date) -> FoodLogEntry {
        log([(food: food, servings: servings ?? food.defaultServings)], as: meal, on: day)[0]
    }

    /// Logs several foods at once, with a single undo. A photo goes on the first entry.
    @discardableResult
    func log(_ foods: [(food: FoodItem, servings: Double)], as meal: MealType, on day: Date,
             photo: Data? = nil) -> [FoodLogEntry] {
        let stamp = meal.logDate(on: day)
        let entries = foods.map { line -> FoodLogEntry in
            line.food.noteLogged(servings: line.servings)
            return FoodLogEntry(food: line.food, servings: line.servings, meal: meal, at: stamp)
        }
        entries.first?.photo = photo
        add(entries, message: Self.loggedMessage(entries))
        return entries
    }

    @discardableResult
    func log(_ recipe: Recipe, servings: Double = 1, as meal: MealType, on day: Date) -> FoodLogEntry {
        let entry = FoodLogEntry(recipe: recipe, servings: servings, meal: meal, at: meal.logDate(on: day))
        add([entry], message: Self.loggedMessage([entry]))
        return entry
    }

    /// Logs every line of a saved meal.
    @discardableResult
    func log(_ saved: SavedMeal, as meal: MealType, on day: Date) -> [FoodLogEntry] {
        let stamp = meal.logDate(on: day)
        let entries = saved.items.map { FoodLogEntry(item: $0, meal: meal, at: stamp) }
        saved.lastUsed = .now
        saved.useCount += 1
        add(entries, message: "Logged \(saved.name)")
        return entries
    }

    /// Logs one portion of a batch and counts it down. Nil when there's none left.
    @discardableResult
    func logPortion(of batch: MealPrepBatch, as meal: MealType, on day: Date) -> FoodLogEntry? {
        guard batch.usePortion() else { return nil }
        let entry = FoodLogEntry(batch: batch, otherNutrients: otherNutrientsPerPortion(of: batch),
                                 meal: meal, at: meal.logDate(on: day))
        add([entry], message: Self.loggedMessage([entry])) {
            batch.portionsLeft += 1
        }
        return entry
    }

    /// Logs a meal-plan item on its day, marks it logged, and counts down its batch if it has one.
    @discardableResult
    func log(_ planned: MealPlanEntry) -> FoodLogEntry {
        let batch = planned.batchID.flatMap { fetchBatch($0) }
        let entry = FoodLogEntry(planned: planned, otherNutrients: otherNutrientsPerServing(of: planned, batch: batch),
                                 at: planned.mealType.logDate(on: planned.day))
        planned.isLogged = true
        let usedPortion = batch?.usePortion() ?? false
        add([entry], message: Self.loggedMessage([entry])) {
            planned.isLogged = false
            if usedPortion { batch?.portionsLeft += 1 }
        }
        return entry
    }

    /// Logs calories (and optionally macros) for something that can't be looked up.
    @discardableResult
    func quickAdd(_ name: String, calories: Double, protein: Double = 0, carbs: Double = 0, fat: Double = 0,
                  as meal: MealType, on day: Date) -> FoodLogEntry {
        let entry = FoodLogEntry(date: meal.logDate(on: day), mealType: meal,
                                 foodName: name.isEmpty ? String(localized: "Quick add") : name,
                                 servings: 1, servingDescription: "",
                                 calories: calories, protein: protein, carbs: carbs, fat: fat)
        add([entry], message: Self.loggedMessage([entry]))
        return entry
    }

    /// Logs a photo with a rough calorie estimate, to be filled in later.
    @discardableResult
    func logEstimate(_ name: String, calories: Double, servingDescription: String, photo: Data?,
                     as meal: MealType, on day: Date) -> FoodLogEntry {
        let entry = FoodLogEntry(date: meal.logDate(on: day), mealType: meal,
                                 foodName: name.isEmpty ? String(localized: "Photo meal") : name, servings: 1,
                                 servingDescription: servingDescription,
                                 calories: calories, protein: 0, carbs: 0, fat: 0)
        entry.photo = photo
        entry.isEstimate = true
        add([entry], message: Self.loggedMessage([entry]))
        return entry
    }

    // MARK: Copying and moving

    /// Logs a past entry again in `meal` on `day`.
    func logAgain(_ entry: FoodLogEntry, as meal: MealType, on day: Date) {
        copy([entry], to: meal, on: day, message: "Logged \(entry.foodName)")
    }

    /// Copies entries to another meal or day, with a single undo.
    func copy(_ entries: [FoodLogEntry], to meal: MealType, on day: Date, message: String? = nil) {
        guard !entries.isEmpty else { return }
        let copies = entries.map { $0.copy(to: meal, on: day) }
        add(copies, message: message ?? (entries.count == 1
            ? "Copied \(entries[0].foodName) to \(meal.inSentence)"
            : "Copied \(entries.count) entries to \(meal.inSentence)"))
    }

    /// Moves entries to another meal or day, updating Health, with a single undo.
    func move(_ entries: [FoodLogEntry], to meal: MealType, on day: Date) {
        let target = meal.logDate(on: day)
        let moving = entries.filter { $0.mealType != meal || !Calendar.current.isDate($0.date, inSameDayAs: target) }
        guard !moving.isEmpty else { return }
        let previous = moving.map { (entry: $0, meal: $0.mealType, date: $0.date) }
        for entry in moving {
            entry.mealType = meal
            entry.date = target
            HealthKitManager.shared.recordDiaryEntry(entry)
        }
        context.saveReportingFailure()
        let message = moving.count == 1
            ? "Moved \(moving[0].foodName) to \(meal.inSentence)"
            : "Moved \(moving.count) entries to \(meal.inSentence)"
        undo?.offer(message) {
            for old in previous {
                old.entry.mealType = old.meal
                old.entry.date = old.date
                HealthKitManager.shared.recordDiaryEntry(old.entry)
            }
            context.saveReportingFailure()
        }
    }

    // MARK: Changing and deleting

    /// Changes an entry's amount (scaling every nutrient) and, optionally, its meal.
    func change(_ entry: FoodLogEntry, servings: Double, meal: MealType? = nil) {
        let previous = (servings: entry.servings, meal: entry.mealType)
        let meal = meal ?? previous.meal
        guard servings > 0, servings != previous.servings || meal != previous.meal else { return }
        entry.scale(toServings: servings)
        entry.mealType = meal
        context.saveReportingFailure()
        HealthKitManager.shared.recordDiaryEntry(entry)
        let message = meal == previous.meal
            ? "Changed \(entry.foodName) to \(servings.cleanString) servings"
            : "Changed \(entry.foodName)"
        undo?.offer(message) {
            entry.scale(toServings: previous.servings)
            entry.mealType = previous.meal
            context.saveReportingFailure()
            HealthKitManager.shared.recordDiaryEntry(entry)
        }
    }

    /// Deletes entries and their Health samples, offering to put them back.
    func delete(_ entries: [FoodLogEntry]) {
        guard !entries.isEmpty else { return }
        if let undo {
            context.deleteDiaryEntries(entries, undo: undo)
        } else {
            for entry in entries { context.deleteDiaryEntry(entry) }
            context.saveReportingFailure()
        }
    }

    // MARK: Helpers

    private func add(_ entries: [FoodLogEntry], message: String, revert: @escaping () -> Void = {}) {
        guard !entries.isEmpty else { return }
        for entry in entries { context.insertDiaryEntry(entry) }
        context.saveReportingFailure()
        undo?.offer(message) {
            for entry in entries { context.deleteDiaryEntry(entry) }
            revert()
            context.saveReportingFailure()
        }
    }

    private static func loggedMessage(_ entries: [FoodLogEntry]) -> String {
        entries.count == 1 ? "Logged \(entries[0].foodName)" : "Logged \(entries.count) entries"
    }

    private func fetchBatch(_ id: UUID) -> MealPrepBatch? {
        try? context.fetch(FetchDescriptor<MealPrepBatch>(predicate: #Predicate { $0.uuid == id })).first
    }

    private func fetchRecipe(_ id: UUID) -> Recipe? {
        try? context.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.uuid == id })).first
    }

    private func fetchFood(_ id: UUID) -> FoodItem? {
        try? context.fetch(FetchDescriptor<FoodItem>(predicate: #Predicate { $0.uuid == id })).first
    }

    /// A batch only snapshots calories and macros, so the rest comes from its recipe, split into
    /// the batch's portions. Zero when the recipe has since been deleted.
    private func otherNutrientsPerPortion(of batch: MealPrepBatch) -> OtherNutrients {
        guard let recipe = batch.recipeID.flatMap({ fetchRecipe($0) }) else { return OtherNutrients() }
        let scale = Double(max(recipe.servings, 1)) / Double(max(batch.portionsTotal, 1))
        return recipe.otherNutrientsPerServing.scaled(by: scale)
    }

    /// A plan item only snapshots calories and macros, so the rest comes from what it links to.
    private func otherNutrientsPerServing(of planned: MealPlanEntry, batch: MealPrepBatch?) -> OtherNutrients {
        if let batch { return otherNutrientsPerPortion(of: batch) }
        if let recipe = planned.recipeID.flatMap({ fetchRecipe($0) }) { return recipe.otherNutrientsPerServing }
        if let food = planned.foodItemID.flatMap({ fetchFood($0) }) { return food.otherNutrients }
        return OtherNutrients()
    }
}

extension FoodItem {
    /// The amount to log when none is given: the last amount logged, or one serving.
    var defaultServings: Double { lastServings ?? 1 }

    /// Remembers a log of this food: the amount for next time, and when and how often it's used.
    func noteLogged(servings: Double) {
        lastServings = servings
        lastUsed = .now
        useCount += 1
    }
}

// MARK: - Snapshots

extension FoodLogEntry {
    /// `servings` of a food.
    convenience init(food: FoodItem, servings: Double, meal: MealType, at date: Date) {
        self.init(date: date, mealType: meal, foodName: food.displayName, servings: servings,
                  servingDescription: food.servingDescription, calories: food.calories * servings,
                  protein: food.protein * servings, carbs: food.carbs * servings, fat: food.fat * servings,
                  foodItemID: food.uuid)
        otherNutrients = food.otherNutrients.scaled(by: servings)
    }

    /// `servings` of a recipe, other nutrients included from its ingredients.
    convenience init(recipe: Recipe, servings: Double, meal: MealType, at date: Date) {
        self.init(date: date, mealType: meal, foodName: recipe.name, servings: servings,
                  servingDescription: String(localized: "serving"),
                  calories: recipe.caloriesPerServing * servings, protein: recipe.proteinPerServing * servings,
                  carbs: recipe.carbsPerServing * servings, fat: recipe.fatPerServing * servings)
        otherNutrients = recipe.otherNutrientsPerServing.scaled(by: servings)
    }

    /// A line of a saved meal.
    convenience init(item: SavedMealItem, meal: MealType, at date: Date) {
        self.init(date: date, mealType: meal, foodName: item.foodName, servings: item.servings,
                  servingDescription: item.servingDescription, calories: item.calories,
                  protein: item.protein, carbs: item.carbs, fat: item.fat, foodItemID: item.foodItemID)
        otherNutrients = item.otherNutrients
    }

    /// One portion of a meal-prep batch.
    convenience init(batch: MealPrepBatch, otherNutrients: OtherNutrients, meal: MealType, at date: Date) {
        self.init(date: date, mealType: meal, foodName: batch.name, servings: 1,
                  servingDescription: String(localized: "portion"),
                  calories: batch.caloriesPerPortion, protein: batch.proteinPerPortion,
                  carbs: batch.carbsPerPortion, fat: batch.fatPerPortion)
        self.otherNutrients = otherNutrients
    }

    /// A meal-plan item, given other nutrients for one serving of it.
    convenience init(planned: MealPlanEntry, otherNutrients: OtherNutrients, at date: Date) {
        self.init(date: date, mealType: planned.mealType, foodName: planned.title, servings: planned.servings,
                  servingDescription: String(localized: "serving"),
                  calories: planned.totalCalories, protein: planned.totalProtein,
                  carbs: planned.totalCarbs, fat: planned.totalFat, foodItemID: planned.foodItemID)
        self.otherNutrients = otherNutrients.scaled(by: planned.servings)
    }
}

// MARK: - Store and Health

extension ModelContext {
    /// Inserts a diary entry and mirrors it to Apple Health when sync is enabled.
    /// Prefer `Diary`, which also saves and offers undo.
    @MainActor
    func insertDiaryEntry(_ entry: FoodLogEntry) {
        insert(entry)
        HealthKitManager.shared.recordDiaryEntry(entry)
    }

    /// Deletes a diary entry and its Health samples. Prefer `Diary`, which also saves and offers undo.
    @MainActor
    func deleteDiaryEntry(_ entry: FoodLogEntry) {
        let id = entry.uuid
        delete(entry)
        HealthKitManager.shared.removeDiaryEntry(id: id)
    }
}
