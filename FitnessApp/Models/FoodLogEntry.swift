import Foundation
import SwiftData

/// A snapshot of something eaten. Values are totals for the logged amount,
/// so editing a food later never rewrites history.
@Model
final class FoodLogEntry {
    var uuid: UUID = UUID()
    var date: Date = Date()
    var mealTypeRaw: String = MealType.snack.rawValue
    var foodName: String = ""
    var servings: Double = 1
    var servingDescription: String = ""
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var sugar: Double = 0
    /// Milligrams.
    var sodium: Double = 0
    var saturatedFat: Double = 0
    /// Milligrams.
    var potassium: Double = 0
    /// Milligrams.
    var cholesterol: Double = 0
    /// Grams of pure alcohol (ethanol).
    var alcohol: Double = 0
    /// Milligrams.
    var caffeine: Double = 0
    var foodItemID: UUID?
    /// A photo of the meal, stored outside the database file.
    @Attribute(.externalStorage) var photo: Data?
    /// Logged from a photo with a rough estimate, to be filled in later.
    var isEstimate: Bool = false

    init(date: Date,
         mealType: MealType,
         foodName: String,
         servings: Double,
         servingDescription: String,
         calories: Double,
         protein: Double,
         carbs: Double,
         fat: Double,
         foodItemID: UUID? = nil,
         fiber: Double = 0,
         sugar: Double = 0,
         sodium: Double = 0) {
        self.uuid = UUID()
        self.date = date
        self.mealTypeRaw = mealType.rawValue
        self.foodName = foodName
        self.servings = servings
        self.servingDescription = servingDescription
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.foodItemID = foodItemID
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    /// Changes the amount, scaling calories and nutrients in proportion.
    func scale(toServings newServings: Double) {
        guard newServings > 0 else { return }
        let ratio = newServings / max(servings, 0.01)
        calories *= ratio
        protein *= ratio
        carbs *= ratio
        fat *= ratio
        fiber *= ratio
        sugar *= ratio
        sodium *= ratio
        saturatedFat *= ratio
        potassium *= ratio
        cholesterol *= ratio
        alcohol *= ratio
        caffeine *= ratio
        servings = newServings
    }

    var servingsLabel: String {
        let qty = servings == servings.rounded() ? String(Int(servings)) : String(format: "%.2g", servings)
        return servingDescription.isEmpty ? "\(qty) serving" : "\(qty) × \(servingDescription)"
    }
}

extension FoodLogEntry {
    /// Copies saturated fat, potassium, cholesterol, alcohol and caffeine from another entry (they
    /// aren't init parameters, to keep the long initialiser manageable).
    @discardableResult
    func withExtras(from other: FoodLogEntry, scale: Double = 1) -> FoodLogEntry {
        saturatedFat = other.saturatedFat * scale
        potassium = other.potassium * scale
        cholesterol = other.cholesterol * scale
        alcohol = other.alcohol * scale
        caffeine = other.caffeine * scale
        return self
    }

    /// The same, from a food for `servings` of it.
    @discardableResult
    func withExtras(from food: FoodItem, servings: Double) -> FoodLogEntry {
        saturatedFat = food.saturatedFat * servings
        potassium = food.potassium * servings
        cholesterol = food.cholesterol * servings
        alcohol = food.alcohol * servings
        caffeine = food.caffeine * servings
        return self
    }
}

extension FoodLogEntry {
    /// A new entry with the same food and amounts in another meal or on another day.
    func copy(to meal: MealType, on day: Date) -> FoodLogEntry {
        let copy = restorableCopy()
        copy.uuid = UUID()
        copy.mealType = meal
        copy.date = meal.logDate(on: day)
        return copy
    }
}

extension ModelContext {
    /// Moves a diary line to another meal or day, updating Health, with undo.
    @MainActor
    func moveDiaryEntry(_ entry: FoodLogEntry, to meal: MealType, on day: Date, undo center: UndoCenter?) {
        let previous = (meal: entry.mealType, date: entry.date)
        let target = meal.logDate(on: day)
        guard previous.meal != meal || !Calendar.current.isDate(previous.date, inSameDayAs: target) else { return }
        entry.mealType = meal
        entry.date = target
        try? save()
        HealthKitManager.shared.recordDiaryEntry(entry)
        center?.offer(String(localized: "Moved \(entry.foodName) to \(meal.inSentence)")) {
            entry.mealType = previous.meal
            entry.date = previous.date
            try? self.save()
            HealthKitManager.shared.recordDiaryEntry(entry)
        }
    }

    /// Copies a diary line to another meal or day, with undo.
    @MainActor
    func copyDiaryEntry(_ entry: FoodLogEntry, to meal: MealType, on day: Date, undo center: UndoCenter?) {
        let copy = entry.copy(to: meal, on: day)
        insertDiaryEntry(copy)
        try? save()
        center?.offer(String(localized: "Copied \(entry.foodName) to \(meal.inSentence)")) {
            self.deleteDiaryEntry(copy)
            try? self.save()
        }
    }

    /// Logs a past diary line again in `meal` on `day`, with undo.
    @MainActor
    func logAgain(_ entry: FoodLogEntry, to meal: MealType, on day: Date, undo center: UndoCenter?) {
        let copy = entry.copy(to: meal, on: day)
        insertDiaryEntry(copy)
        try? save()
        center?.offer(String(localized: "Logged \(entry.foodName)")) {
            self.deleteDiaryEntry(copy)
            try? self.save()
        }
    }

    /// Moves several diary lines at once, with a single undo.
    @MainActor
    func moveDiaryEntries(_ entries: [FoodLogEntry], to meal: MealType, on day: Date, undo center: UndoCenter?) {
        guard !entries.isEmpty else { return }
        if entries.count == 1 { return moveDiaryEntry(entries[0], to: meal, on: day, undo: center) }
        let previous = entries.map { (entry: $0, meal: $0.mealType, date: $0.date) }
        let target = meal.logDate(on: day)
        for entry in entries {
            entry.mealType = meal
            entry.date = target
            HealthKitManager.shared.recordDiaryEntry(entry)
        }
        try? save()
        center?.offer(String(localized: "Moved \(entries.count) entries to \(meal.inSentence)")) {
            for old in previous {
                old.entry.mealType = old.meal
                old.entry.date = old.date
                HealthKitManager.shared.recordDiaryEntry(old.entry)
            }
            try? self.save()
        }
    }

    /// Copies several diary lines at once, with a single undo.
    @MainActor
    func copyDiaryEntries(_ entries: [FoodLogEntry], to meal: MealType, on day: Date, undo center: UndoCenter?) {
        guard !entries.isEmpty else { return }
        if entries.count == 1 { return copyDiaryEntry(entries[0], to: meal, on: day, undo: center) }
        let copies = entries.map { $0.copy(to: meal, on: day) }
        for copy in copies { insertDiaryEntry(copy) }
        try? save()
        center?.offer(String(localized: "Copied \(entries.count) entries to \(meal.inSentence)")) {
            for copy in copies { self.deleteDiaryEntry(copy) }
            try? self.save()
        }
    }
}
