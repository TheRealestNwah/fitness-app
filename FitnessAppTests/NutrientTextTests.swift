import XCTest
@testable import FitnessApp

final class NutrientTextTests: XCTestCase {
    func testPlanSummaryAndTodayShowTheSameGrams() {
        // 1583 kcal at 30/40/30 is 118.7 g protein and 52.8 g fat. Truncating showed 118 and 52
        // on the plan summary while Today rounded to 119 and 53.
        let macros = NutritionCalculator.macroGrams(calories: 1583, proteinPercent: 30, carbsPercent: 40, fatPercent: 30)
        XCTAssertEqual(NutrientText.grams(macros.protein), 119)
        XCTAssertEqual(NutrientText.grams(macros.carbs), 158)
        XCTAssertEqual(NutrientText.grams(macros.fat), 53)
    }

    func testMissingNutrientsShowADash() {
        XCTAssertEqual(NutrientText.amount(0, unit: "g", goal: nil), "–")
        XCTAssertEqual(NutrientText.amount(0, unit: "mg", goal: 2300), "– / 2300 mg")
    }

    func testListedNutrientsShowTheirUnit() {
        XCTAssertEqual(NutrientText.amount(12, unit: "g", goal: nil), "12 g")
        XCTAssertEqual(NutrientText.amount(12, unit: "g", goal: 30), "12 / 30 g")
        XCTAssertEqual(NutrientText.amount(1.5, unit: "", goal: nil, fractionDigits: 1), "1.5")
    }
}
