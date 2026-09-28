import Foundation
import SwiftData

/// One planned item on a given day. Stores a nutrition snapshot for a single serving
/// plus an optional link back to the recipe or food it came from.
@Model
final class MealPlanEntry {
    var uuid: UUID = UUID()
    var day: Date = Date()
    var mealTypeRaw: String = MealType.dinner.rawValue
    var title: String = ""
    var servings: Double = 1
    var caloriesPerServing: Double = 0
    var proteinPerServing: Double = 0
    var carbsPerServing: Double = 0
    var fatPerServing: Double = 0
    var recipeID: UUID?
    var foodItemID: UUID?
    var isLogged: Bool = false

    init(day: Date,
         mealType: MealType,
         title: String,
         servings: Double = 1,
         caloriesPerServing: Double,
         proteinPerServing: Double,
         carbsPerServing: Double,
         fatPerServing: Double,
         recipeID: UUID? = nil,
         foodItemID: UUID? = nil) {
        self.uuid = UUID()
        self.day = Calendar.current.startOfDay(for: day)
        self.mealTypeRaw = mealType.rawValue
        self.title = title
        self.servings = servings
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.carbsPerServing = carbsPerServing
        self.fatPerServing = fatPerServing
        self.recipeID = recipeID
        self.foodItemID = foodItemID
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .dinner }
        set { mealTypeRaw = newValue.rawValue }
    }

    var totalCalories: Double { caloriesPerServing * servings }
    var totalProtein: Double { proteinPerServing * servings }
    var totalCarbs: Double { carbsPerServing * servings }
    var totalFat: Double { fatPerServing * servings }
}

extension MealPlanEntry {
    /// One serving of a recipe in a plan slot.
    convenience init(recipe: Recipe, day: Date, mealType: MealType) {
        self.init(day: day, mealType: mealType, title: recipe.name,
                  caloriesPerServing: recipe.caloriesPerServing,
                  proteinPerServing: recipe.proteinPerServing,
                  carbsPerServing: recipe.carbsPerServing,
                  fatPerServing: recipe.fatPerServing,
                  recipeID: recipe.uuid)
    }

    /// One serving of a saved food in a plan slot.
    convenience init(food: FoodItem, day: Date, mealType: MealType) {
        self.init(day: day, mealType: mealType, title: food.displayName,
                  caloriesPerServing: food.calories,
                  proteinPerServing: food.protein,
                  carbsPerServing: food.carbs,
                  fatPerServing: food.fat,
                  foodItemID: food.uuid)
    }
}
