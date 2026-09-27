import XCTest
@testable import FitnessApp

final class RecipeScalerTests: XCTestCase {
    func testScalesLeadingQuantityAndBracketedWeight() {
        XCTAssertEqual(RecipeScaler.scale("1/2 cup (40 g)", by: 2), "1 cup (80 g)")
        XCTAssertEqual(RecipeScaler.scale("2 large", by: 1.5), "3 large")
        XCTAssertEqual(RecipeScaler.scale("1 tbsp", by: 0.5), "½ tbsp")
        XCTAssertEqual(RecipeScaler.scale("1 1/2 cups", by: 2), "3 cups")
        XCTAssertEqual(RecipeScaler.scale("120 g", by: 1.5), "180 g")
    }

    func testLeavesTextWithoutNumbersAlone() {
        XCTAssertEqual(RecipeScaler.scale("handful", by: 3), "handful")
        XCTAssertEqual(RecipeScaler.scale("1 cup", by: 1), "1 cup")
    }

    func testKitchenFractions() {
        XCTAssertEqual(RecipeScaler.formatQuantity(0.75), "¾")
        XCTAssertEqual(RecipeScaler.formatQuantity(2.5), "2½")
        XCTAssertEqual(RecipeScaler.formatQuantity(1.0 / 3), "⅓")
        XCTAssertEqual(RecipeScaler.formatQuantity(1.1), "1.1")
        XCTAssertEqual(RecipeScaler.formatQuantity(0.02), "0.02")
    }
}

final class RecipeImporterTests: XCTestCase {
    private let page = """
    <html><head><title>x</title>
    <script type="application/ld+json">{"@context":"https://schema.org","@type":"WebSite","name":"Site"}</script>
    <script type="application/ld+json">
    {"@context":"https://schema.org","@graph":[{"@type":"Organization"},
     {"@type":["Recipe"],"name":"Lemon &amp; Herb Chicken","recipeYield":["4","4 servings"],"totalTime":"PT1H15M",
      "recipeIngredient":["4 chicken thighs","1 tbsp olive oil","&frac12; lemon"],
      "recipeInstructions":[{"@type":"HowToStep","text":"Heat the oven."},
                            {"@type":"HowToSection","itemListElement":[{"@type":"HowToStep","text":"Roast <b>40</b> min."}]}],
      "nutrition":{"@type":"NutritionInformation","calories":"420 kcal","proteinContent":"35 g","fatContent":"22g"}}]}
    </script></head></html>
    """

    func testReadsARecipeFromJSONLD() throws {
        let recipe = try XCTUnwrap(RecipeImporter.parse(html: page))
        XCTAssertEqual(recipe.name, "Lemon & Herb Chicken")
        XCTAssertEqual(recipe.servings, 4)
        XCTAssertEqual(recipe.prepMinutes, 75)
        XCTAssertEqual(recipe.ingredients, ["4 chicken thighs", "1 tbsp olive oil", "½ lemon"])
        XCTAssertTrue(recipe.instructions.contains("Heat the oven."))
        XCTAssertTrue(recipe.instructions.contains("Roast 40 min."))
        XCTAssertEqual(recipe.calories, 420)
        XCTAssertEqual(recipe.protein, 35)
        XCTAssertEqual(recipe.fat, 22)
        XCTAssertNil(recipe.carbs)
    }

    func testNoRecipeOnThePage() {
        XCTAssertNil(RecipeImporter.parse(html: "<html><script type='application/ld+json'>{\"@type\":\"Article\"}</script></html>"))
        XCTAssertNil(RecipeImporter.parse(html: "<html>plain</html>"))
    }

    func testDurationsAndYields() {
        XCTAssertEqual(RecipeImporter.minutes("PT30M"), 30)
        XCTAssertEqual(RecipeImporter.minutes("PT2H"), 120)
        XCTAssertEqual(RecipeImporter.minutes(nil), 15)
        XCTAssertEqual(RecipeImporter.servings("6 portions"), 6)
        XCTAssertEqual(RecipeImporter.servings(2), 2)
        XCTAssertEqual(RecipeImporter.servings(nil), 1)
    }
}
