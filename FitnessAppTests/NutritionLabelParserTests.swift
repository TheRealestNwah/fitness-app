import XCTest
@testable import FitnessApp

final class NutritionLabelParserTests: XCTestCase {
    func testUSNutritionFactsPanel() {
        let lines = ["Nutrition Facts", "8 servings per container", "Serving size 2/3 cup (55g)",
                     "Amount per serving", "Calories 230", "% Daily Value*",
                     "Total Fat 8g 10%", "Saturated Fat 1g 5%", "Trans Fat 0g", "Cholesterol 0mg 0%",
                     "Sodium 160mg 7%", "Total Carbohydrate 37g 13%", "Dietary Fiber 4g 14%",
                     "Total Sugars 12g", "Includes 10g Added Sugars 20%", "Protein 3g",
                     "2,000 calories a day is used for general nutrition advice."]
        let label = NutritionLabelParser.parse(lines)
        XCTAssertFalse(label.per100g)
        XCTAssertEqual(label.servingDescription, "2/3 cup (55g)")
        XCTAssertEqual(label.servingGrams, 55)
        XCTAssertEqual(label.calories, 230)
        XCTAssertEqual(label.fat, 8)
        XCTAssertEqual(label.sodiumMg, 160)
        XCTAssertEqual(label.carbs, 37)
        XCTAssertEqual(label.fiber, 4)
        XCTAssertEqual(label.sugar, 12)
        XCTAssertEqual(label.protein, 3)
        XCTAssertEqual(label.saturatedFat, 1)
        XCTAssertEqual(label.cholesterolMg, 0)
        XCTAssertNil(label.potassiumMg)
    }

    func testPotassiumAndCholesterolInMilligrams() {
        let label = NutritionLabelParser.parse(["Calories 150", "Cholesterol 35mg 12%", "Potassium 470mg 10%"])
        XCTAssertEqual(label.cholesterolMg, 35)
        XCTAssertEqual(label.potassiumMg, 470)
    }

    func testCaloriesOnTheNextLine() {
        XCTAssertEqual(NutritionLabelParser.parse(["Calories", "250", "Protein 5g"]).calories, 250)
    }

    func testUKTableUsesPer100gColumnAndSalt() {
        let lines = ["Typical values Per 100g Per 30g serving",
                     "Energy 1590kJ / 378kcal 477kJ / 113kcal",
                     "Fat 7.6g 2.3g", "of which saturates 1.2g 0.4g",
                     "Carbohydrate 60g 18g", "of which sugars 11g 3.3g",
                     "Fibre 8.5g 2.6g", "Protein 11g 3.3g", "Salt 0.45g 0.14g"]
        let label = NutritionLabelParser.parse(lines)
        XCTAssertTrue(label.per100g)
        XCTAssertEqual(label.servingGrams, 30)
        XCTAssertEqual(label.calories, 378)
        XCTAssertEqual(label.saturatedFat, 1.2)
        XCTAssertEqual(label.fat, 7.6)
        XCTAssertEqual(label.carbs, 60)
        XCTAssertEqual(label.sugar, 11)
        XCTAssertEqual(label.fiber, 8.5)
        XCTAssertEqual(label.protein, 11)
        XCTAssertEqual(label.sodiumMg, 180)
    }

    func testEUEnergyInKilojoulesOnlyAndDecimalCommas() {
        let lines = ["Nährwerte pro 100 g", "Energy 1046 kJ", "Fat 12,5 g", "Carbohydrate 31 g", "Protein 5,2 g"]
        let label = NutritionLabelParser.parse(lines)
        XCTAssertTrue(label.per100g)
        XCTAssertEqual(label.calories, 250)
        XCTAssertEqual(label.fat, 12.5)
        XCTAssertEqual(label.protein, 5.2)
    }

    func testKilocaloriesOnTheLineAfterKilojoules() {
        XCTAssertEqual(NutritionLabelParser.parse(["Energy 1046 kJ", "250 kcal"]).calories, 250)
    }

    func testNothingReadable() {
        XCTAssertTrue(NutritionLabelParser.parse(["Best before end", "see lid"]).isEmpty)
    }

    func testGroupsRecognisedPiecesIntoRows() {
        let rows = LabelTextRecognizer.rows([
            (CGRect(x: 0.6, y: 0.50, width: 0.2, height: 0.04), "3g"),
            (CGRect(x: 0.1, y: 0.505, width: 0.3, height: 0.04), "Protein"),
            (CGRect(x: 0.1, y: 0.60, width: 0.3, height: 0.04), "Fat 8g"),
        ])
        XCTAssertEqual(rows, ["Fat 8g", "Protein 3g"])
    }
}
