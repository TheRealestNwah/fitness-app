import Foundation
import SwiftData

/// One line of a favourite meal. A snapshot, like a diary entry, so it survives food edits.
struct SavedMealItem: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var foodName: String
    var servings: Double
    var servingDescription: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var foodItemID: UUID?
    // Optional so meals saved before these were tracked still decode.
    var fiber: Double?
    var sugar: Double?
    var sodium: Double?
    var saturatedFat: Double?
    var potassium: Double?
    var cholesterol: Double?
    var alcohol: Double?
    var caffeine: Double?

    init(foodName: String, servings: Double, servingDescription: String,
         calories: Double, protein: Double, carbs: Double, fat: Double, foodItemID: UUID? = nil) {
        self.id = UUID()
        self.foodName = foodName
        self.servings = servings
        self.servingDescription = servingDescription
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.foodItemID = foodItemID
    }

    init(entry: FoodLogEntry) {
        self.init(foodName: entry.foodName, servings: entry.servings, servingDescription: entry.servingDescription,
                  calories: entry.calories, protein: entry.protein, carbs: entry.carbs, fat: entry.fat,
                  foodItemID: entry.foodItemID)
        fiber = entry.fiber
        sugar = entry.sugar
        sodium = entry.sodium
        saturatedFat = entry.saturatedFat
        potassium = entry.potassium
        cholesterol = entry.cholesterol
        alcohol = entry.alcohol
        caffeine = entry.caffeine
    }
}

/// A named group of diary lines the user eats often, logged again with one tap.
@Model
final class SavedMeal {
    var uuid: UUID = UUID()
    var name: String = ""
    var mealTypeRaw: String = MealType.snack.rawValue
    var items: [SavedMealItem] = []
    var createdAt: Date = Date()
    var lastUsed: Date?
    var useCount: Int = 0
    /// A photo of the meal, stored outside the database file. Shown as a thumbnail in search.
    @Attribute(.externalStorage) var photo: Data?

    init(name: String, mealType: MealType, items: [SavedMealItem]) {
        self.uuid = UUID()
        self.name = name
        self.mealTypeRaw = mealType.rawValue
        self.items = items
        self.createdAt = Date()
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { items.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Double { items.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double { items.reduce(0) { $0 + $1.fat } }

    var summary: String {
        items.map(\.foodName).joined(separator: ", ")
    }

    /// The photo a new favourite starts with: the first one among the diary lines it's made from.
    static func firstPhoto(in entries: [FoodLogEntry]) -> Data? {
        entries.lazy.compactMap(\.photo).first
    }

    /// Inserts a diary entry for each item and returns them.
    @MainActor
    @discardableResult
    func log(on day: Date, as meal: MealType, context: ModelContext) -> [FoodLogEntry] {
        let stamp = meal.logDate(on: day)
        let entries = items.map { item in
            let entry = FoodLogEntry(date: stamp, mealType: meal, foodName: item.foodName, servings: item.servings,
                                     servingDescription: item.servingDescription, calories: item.calories,
                                     protein: item.protein, carbs: item.carbs, fat: item.fat, foodItemID: item.foodItemID,
                                     fiber: item.fiber ?? 0, sugar: item.sugar ?? 0, sodium: item.sodium ?? 0)
            entry.saturatedFat = item.saturatedFat ?? 0
            entry.potassium = item.potassium ?? 0
            entry.cholesterol = item.cholesterol ?? 0
            entry.alcohol = item.alcohol ?? 0
            entry.caffeine = item.caffeine ?? 0
            return entry
        }
        for e in entries { context.insertDiaryEntry(e) }
        lastUsed = .now
        useCount += 1
        return entries
    }
}
