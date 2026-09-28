import Foundation
import SwiftData

/// A recipe cooked once and eaten over several days. Logging a portion counts it down; the
/// batch shows in food search and the meal planner until it's used up.
@Model
final class MealPrepBatch {
    var uuid: UUID = UUID()
    var name: String = ""
    var recipeID: UUID?
    var cookedAt: Date = Date()
    var portionsTotal: Int = 1
    var portionsLeft: Int = 1
    /// Nutrition for one portion, snapshotted so later recipe edits don't change the batch.
    var caloriesPerPortion: Double = 0
    var proteinPerPortion: Double = 0
    var carbsPerPortion: Double = 0
    var fatPerPortion: Double = 0

    init(recipe: Recipe, portions: Int, cookedAt: Date = .now) {
        self.uuid = UUID()
        self.name = recipe.name
        self.recipeID = recipe.uuid
        self.cookedAt = cookedAt
        let portions = max(portions, 1)
        self.portionsTotal = portions
        self.portionsLeft = portions
        // The recipe's nutrition is per its own serving; a batch may be split differently.
        let scale = Double(max(recipe.servings, 1)) / Double(portions)
        self.caloriesPerPortion = recipe.caloriesPerServing * scale
        self.proteinPerPortion = recipe.proteinPerServing * scale
        self.carbsPerPortion = recipe.carbsPerServing * scale
        self.fatPerPortion = recipe.fatPerServing * scale
    }

    var isUsedUp: Bool { portionsLeft <= 0 }

    /// Counts one portion down. False when there's none left.
    @discardableResult
    func usePortion() -> Bool {
        guard portionsLeft > 0 else { return false }
        portionsLeft -= 1
        return true
    }

    /// Logs one portion to the diary (and Health) and counts it down.
    @MainActor
    @discardableResult
    func logPortion(on day: Date, as meal: MealType, context: ModelContext) -> FoodLogEntry? {
        guard usePortion() else { return nil }
        let entry = FoodLogEntry(date: meal.logDate(on: day), mealType: meal, foodName: name,
                                 servings: 1, servingDescription: String(localized: "portion"),
                                 calories: caloriesPerPortion, protein: proteinPerPortion,
                                 carbs: carbsPerPortion, fat: fatPerPortion)
        context.insertDiaryEntry(entry)
        return entry
    }
}
