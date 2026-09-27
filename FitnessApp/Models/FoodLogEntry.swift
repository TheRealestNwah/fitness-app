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
    var foodItemID: UUID?

    init(date: Date,
         mealType: MealType,
         foodName: String,
         servings: Double,
         servingDescription: String,
         calories: Double,
         protein: Double,
         carbs: Double,
         fat: Double,
         foodItemID: UUID? = nil) {
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
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    var servingsLabel: String {
        let qty = servings == servings.rounded() ? String(Int(servings)) : String(format: "%.2g", servings)
        return servingDescription.isEmpty ? "\(qty) serving" : "\(qty) × \(servingDescription)"
    }
}
