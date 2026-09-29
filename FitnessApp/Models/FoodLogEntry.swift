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
        servings = newServings
    }

    var servingsLabel: String {
        let qty = servings == servings.rounded() ? String(Int(servings)) : String(format: "%.2g", servings)
        return servingDescription.isEmpty ? "\(qty) serving" : "\(qty) × \(servingDescription)"
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
}
