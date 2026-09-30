import XCTest
@testable import FitnessApp

final class RecipeTextParserTests: XCTestCase {
    func testCookbookPageWithHeadings() throws {
        let lines = [
            "Lemon Chicken Traybake",
            "Serves 4",
            "Prep 15 min",
            "Cook 40 min",
            "Ingredients",
            "• 8 chicken thighs",
            "• 1½ tbsp olive oil",
            "2 lemons",
            "500g baby potatoes",
            "Salt to taste",
            "Method",
            "1. Heat the oven to 200C. Toss the potatoes in half the oil",
            "and roast for 10 minutes.",
            "2. Add the chicken and lemon, then roast for 30 minutes more.",
        ]
        let recipe = try XCTUnwrap(RecipeTextParser.parse(lines: lines))
        XCTAssertEqual(recipe.name, "Lemon Chicken Traybake")
        XCTAssertEqual(recipe.servings, 4)
        XCTAssertEqual(recipe.prepMinutes, 55)
        XCTAssertEqual(recipe.ingredients, ["8 chicken thighs", "1 1/2 tbsp olive oil", "2 lemons", "500g baby potatoes",
                                            "Salt to taste"])
        XCTAssertEqual(recipe.instructions.components(separatedBy: "\n").count, 2)
        XCTAssertTrue(recipe.instructions.hasPrefix("1. Heat the oven to 200C. Toss the potatoes in half the oil and roast"))
    }

    func testCardWithoutHeadings() throws {
        let lines = [
            "Banana Oat Pancakes",
            "Makes 2",
            "2 ripe bananas",
            "1 cup rolled oats",
            "2 eggs",
            "Blend everything until smooth and leave the batter to rest for five minutes.",
            "Cook spoonfuls in a hot non-stick pan for two minutes on each side.",
        ]
        let recipe = try XCTUnwrap(RecipeTextParser.parse(lines: lines))
        XCTAssertEqual(recipe.name, "Banana Oat Pancakes")
        XCTAssertEqual(recipe.servings, 2)
        XCTAssertEqual(recipe.ingredients, ["2 ripe bananas", "1 cup rolled oats", "2 eggs"])
        XCTAssertTrue(recipe.instructions.hasPrefix("Blend everything"))
    }

    func testTotalTimeWinsOverParts() {
        let recipe = RecipeTextParser.parse(lines: ["Soup", "Prep 10 min", "Total time 1 hr 5 mins", "Ingredients", "1 onion"])
        XCTAssertEqual(recipe?.prepMinutes, 65)
    }

    func testNoIngredientsMeansNoRecipe() {
        XCTAssertNil(RecipeTextParser.parse(lines: []))
        XCTAssertNil(RecipeTextParser.parse(lines: ["A lovely afternoon in the garden with a cup of tea and a good book."]))
    }

    func testCleanTurnsFractionGlyphsIntoText() {
        XCTAssertEqual(RecipeTextParser.clean("• 1½ cups milk"), "1 1/2 cups milk")
        XCTAssertEqual(RecipeTextParser.clean("¾ tsp salt"), "3/4 tsp salt")
    }

    func testStepsAreNotIngredients() {
        XCTAssertFalse(RecipeTextParser.looksLikeIngredient("1. Preheat the oven"))
        XCTAssertTrue(RecipeTextParser.looksLikeIngredient("1.5 kg potatoes"))
    }

    func testMatchesIngredientLinesToSavedFoods() {
        let oats = FoodItem(name: "Rolled oats", servingDescription: "1/2 cup (40 g)", calories: 150, protein: 5, carbs: 27, fat: 3)
        let egg = FoodItem(name: "Egg", servingDescription: "1 large (50 g)", calories: 72, protein: 6.3, carbs: 0.4, fat: 4.8)
        let eggs = RecipeIngredientMatcher.ingredient(for: "2 eggs", foods: [oats, egg])
        XCTAssertEqual(eggs.name, "2 eggs")
        XCTAssertEqual(eggs.calories, 144, accuracy: 0.01)
        let unknown = RecipeIngredientMatcher.ingredient(for: "1 tsp za'atar", foods: [oats, egg])
        XCTAssertEqual(unknown.calories, 0)
    }
}
