import XCTest
@testable import FitnessApp

final class FoodLogEntryTests: XCTestCase {
    func testScalingChangesNutrientsInProportion() {
        let entry = FoodLogEntry(date: .now, mealType: .lunch, foodName: "Rice", servings: 2, servingDescription: "1 cup",
                                 calories: 400, protein: 8, carbs: 88, fat: 1, fiber: 2, sugar: 0.2, sodium: 10)
        entry.scale(toServings: 3)
        XCTAssertEqual(entry.servings, 3)
        XCTAssertEqual(entry.calories, 600, accuracy: 0.001)
        XCTAssertEqual(entry.protein, 12, accuracy: 0.001)
        XCTAssertEqual(entry.carbs, 132, accuracy: 0.001)
        XCTAssertEqual(entry.fat, 1.5, accuracy: 0.001)
        XCTAssertEqual(entry.fiber, 3, accuracy: 0.001)
        XCTAssertEqual(entry.sodium, 15, accuracy: 0.001)
        XCTAssertEqual(entry.servingsLabel, "3 × 1 cup")
    }

    func testScalingIgnoresZero() {
        let entry = FoodLogEntry(date: .now, mealType: .snack, foodName: "Apple", servings: 1, servingDescription: "1 medium",
                                 calories: 95, protein: 0.5, carbs: 25, fat: 0.3)
        entry.scale(toServings: 0)
        XCTAssertEqual(entry.servings, 1)
        XCTAssertEqual(entry.calories, 95)
    }
}
