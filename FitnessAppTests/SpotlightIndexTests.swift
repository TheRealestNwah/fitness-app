import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class SpotlightIndexTests: XCTestCase {
    private func food(_ name: String, custom: Bool = false, favorite: Bool = false, used: Bool = false) -> FoodItem {
        let item = FoodItem(name: name, brand: custom ? "Home" : "", servingDescription: "1 serving",
                            calories: 100, protein: 1, carbs: 1, fat: 1, isCustom: custom)
        item.isFavorite = favorite
        item.lastUsed = used ? .now : nil
        return item
    }

    func testIndexesSavedFoodsRecipesAndMeals() {
        let foods = [food("Apple"), food("Granola", custom: true), food("Kiwi", favorite: true), food("Tea", used: true)]
        let recipe = Recipe(name: "Chili", mealType: .dinner, servings: 2, prepMinutes: 30,
                            ingredients: [Ingredient(name: "Beans", amount: "1 can", calories: 400, protein: 20, carbs: 60, fat: 2)],
                            instructions: "", tags: ["spicy"])
        let meal = SavedMeal(name: "Usual breakfast", mealType: .breakfast,
                             items: [SavedMealItem(foodName: "Oats", servings: 1, servingDescription: "40 g",
                                                   calories: 150, protein: 5, carbs: 27, fat: 3)])

        let entries = SpotlightIndex.entries(foods: foods, recipes: [recipe], meals: [meal])

        XCTAssertEqual(entries.map(\.title), ["Granola (Home)", "Kiwi", "Tea", "Chili", "Usual breakfast"])
        XCTAssertEqual(entries.first?.keywords, ["Home"])
        XCTAssertEqual(entries[3].keywords, ["spicy", "Beans"])
        XCTAssertEqual(entries[4].keywords, ["Oats"])
    }

    func testIdentifiersRoundTrip() {
        let id = UUID()
        let entry = SpotlightIndex.Entry(domain: .recipe, id: id, title: "", detail: "", keywords: [])
        XCTAssertEqual(SpotlightIndex.Target(identifier: entry.identifier), .recipe(id))
        XCTAssertEqual(SpotlightIndex.Target(identifier: "food.\(id.uuidString)"), .food(id))
        XCTAssertEqual(SpotlightIndex.Target(identifier: "meal.\(id.uuidString)"), .meal(id))
        XCTAssertNil(SpotlightIndex.Target(identifier: "weight.\(id.uuidString)"))
        XCTAssertNil(SpotlightIndex.Target(identifier: "food.not-a-uuid"))
    }
}
