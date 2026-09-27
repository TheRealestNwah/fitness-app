import Foundation
import SwiftData

struct Ingredient: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var amount: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    init(name: String, amount: String, calories: Double, protein: Double, carbs: Double, fat: Double) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

@Model
final class Recipe {
    var uuid: UUID = UUID()
    var name: String = ""
    var mealTypeRaw: String = MealType.dinner.rawValue
    var servings: Int = 1
    var prepMinutes: Int = 15
    var ingredients: [Ingredient] = []
    var instructions: String = ""
    var tags: [String] = []
    var isFavorite: Bool = false
    var isCustom: Bool = false

    init(name: String,
         mealType: MealType,
         servings: Int,
         prepMinutes: Int,
         ingredients: [Ingredient],
         instructions: String,
         tags: [String] = [],
         isCustom: Bool = false) {
        self.uuid = UUID()
        self.name = name
        self.mealTypeRaw = mealType.rawValue
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.ingredients = ingredients
        self.instructions = instructions
        self.tags = tags
        self.isCustom = isCustom
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .dinner }
        set { mealTypeRaw = newValue.rawValue }
    }

    private var divisor: Double { Double(max(servings, 1)) }

    var caloriesPerServing: Double { ingredients.reduce(0) { $0 + $1.calories } / divisor }
    var proteinPerServing: Double { ingredients.reduce(0) { $0 + $1.protein } / divisor }
    var carbsPerServing: Double { ingredients.reduce(0) { $0 + $1.carbs } / divisor }
    var fatPerServing: Double { ingredients.reduce(0) { $0 + $1.fat } / divisor }
}
