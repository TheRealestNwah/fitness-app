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
        self.isCustom = isCustom
    }

    var displayName: String {
        brand.isEmpty ? name : "\(name) (\(brand))"
    }
}
