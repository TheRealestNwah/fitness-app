import Foundation
import SwiftData

/// A household measure for a food, e.g. "1 slice" = 0.5 servings.
struct ServingPreset: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var label: String
    var servings: Double
}

@Model
final class FoodItem {
    var uuid: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var servingDescription: String = "1 serving"
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var sugar: Double = 0
    /// Milligrams.
    var sodium: Double = 0
    var isFavorite: Bool = false
    var isCustom: Bool = false
    var lastUsed: Date?
    var useCount: Int = 0
    /// Product barcode when the food came from a scan, so the next scan is instant and offline.
    var barcode: String?
    /// Household measures offered alongside servings and grams.
    var servingPresets: [ServingPreset] = []
    /// The amount last logged, used as the default next time.
    var lastServings: Double?

    init(name: String,
         brand: String = "",
         servingDescription: String,
         calories: Double,
         protein: Double,
         carbs: Double,
         fat: Double,
         fiber: Double = 0,
         sugar: Double = 0,
         sodium: Double = 0,
         isCustom: Bool = false) {
        self.uuid = UUID()
        self.name = name
        self.brand = brand
        self.servingDescription = servingDescription
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.isCustom = isCustom
    }

    var displayName: String {
        brand.isEmpty ? name : "\(name) (\(brand))"
    }
}

extension FoodItem {
    /// Adds this food to the diary and remembers the amount for next time.
    @discardableResult
    func log(servings: Double, meal: MealType, on date: Date, context: ModelContext) -> FoodLogEntry {
        lastServings = servings
        let entry = FoodLogEntry(date: meal.logDate(on: date),
                                 mealType: meal,
                                 foodName: displayName,
                                 servings: servings,
                                 servingDescription: servingDescription,
                                 calories: calories * servings,
                                 protein: protein * servings,
                                 carbs: carbs * servings,
                                 fat: fat * servings,
                                 foodItemID: uuid,
                                 fiber: fiber * servings,
                                 sugar: sugar * servings,
                                 sodium: sodium * servings)
        context.insert(entry)
        lastUsed = .now
        useCount += 1
        return entry
    }
}
