import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class ExtraNutrientsTests: XCTestCase {
    func testLoggingAFoodCarriesItsExtraNutrients() throws {
        let container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let food = FoodItem(name: "Cheddar", servingDescription: "30 g", calories: 120, protein: 7, carbs: 0.4, fat: 10)
        food.saturatedFat = 6
        food.potassium = 25
        food.cholesterol = 30
        let entry = food.log(servings: 2, meal: .lunch, on: .now, context: container.mainContext)
        XCTAssertEqual(entry.saturatedFat, 12)
        XCTAssertEqual(entry.potassium, 50)
        XCTAssertEqual(entry.cholesterol, 60)
    }

    func testSavedMealsKeepExtraNutrients() throws {
        let container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let original = FoodLogEntry(date: .now, mealType: .lunch, foodName: "Cheddar", servings: 1,
                                    servingDescription: "30 g", calories: 120, protein: 7, carbs: 0.4, fat: 10)
        original.saturatedFat = 6
        original.cholesterol = 30
        let meal = SavedMeal(name: "Cheese", mealType: .snack, items: [SavedMealItem(entry: original)])
        let logged = meal.log(on: .now, as: .snack, context: container.mainContext)
        XCTAssertEqual(logged.first?.saturatedFat, 6)
        XCTAssertEqual(logged.first?.cholesterol, 30)
        XCTAssertEqual(original.restorableCopy().saturatedFat, 6)
    }
}
