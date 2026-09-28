import XCTest
@testable import FitnessApp

final class MealSuggesterTests: XCTestCase {
    private let target = MealSuggester.Macros(kcal: 2000, protein: 140, carbs: 200, fat: 70)

    private func food(_ name: String, _ kcal: Double, p: Double = 0, c: Double = 0, f: Double = 0) -> MealSuggester.Candidate {
        .init(kind: .food(UUID()), name: name, detail: "", macros: .init(kcal: kcal, protein: p, carbs: c, fat: f))
    }

    func testNothingWhenAlmostOutOfCalories() {
        let remaining = MealSuggester.Macros(kcal: 80, protein: 30, carbs: 10, fat: 5)
        XCTAssertTrue(MealSuggester.suggestions(remaining: remaining, target: target,
                                                candidates: [food("Apple", 60, c: 15)]).isEmpty)
    }

    func testLeavesOutWhatWouldGoOverBudget() {
        let remaining = MealSuggester.Macros(kcal: 400, protein: 40, carbs: 40, fat: 15)
        let picks = MealSuggester.suggestions(remaining: remaining, target: target,
                                              candidates: [food("Pizza", 900, p: 35, c: 100, f: 40),
                                                           food("Chicken salad", 380, p: 35, c: 20, f: 15)])
        XCTAssertEqual(picks.map(\.name), ["Chicken salad"])
    }

    func testFavoursProteinWhenProteinIsBehind() {
        // Carbs and fat almost met, protein far behind.
        let remaining = MealSuggester.Macros(kcal: 500, protein: 60, carbs: 15, fat: 5)
        let picks = MealSuggester.suggestions(remaining: remaining, target: target,
                                              candidates: [food("Pasta", 450, p: 12, c: 80, f: 8),
                                                           food("Greek yoghurt", 180, p: 20, c: 8, f: 2),
                                                           food("Chicken breast", 250, p: 45, c: 0, f: 5)])
        XCTAssertEqual(picks.first?.name, "Chicken breast")
        XCTAssertEqual(picks.last?.name, "Pasta")
    }

    func testTokenAmountsRankBelowProperMeals() {
        let remaining = MealSuggester.Macros(kcal: 600, protein: 40, carbs: 70, fat: 20)
        let picks = MealSuggester.suggestions(remaining: remaining, target: target,
                                              candidates: [food("Mint", 5, c: 1),
                                                           food("Salmon rice bowl", 550, p: 35, c: 60, f: 18)])
        XCTAssertEqual(picks.first?.name, "Salmon rice bowl")
    }

    func testDedupesByNameAndLimits() {
        let remaining = MealSuggester.Macros(kcal: 800, protein: 50, carbs: 80, fat: 25)
        let many = (0..<10).map { food("Food \($0)", Double(200 + $0 * 20), p: 10, c: 20, f: 5) }
            + [food("food 1", 220, p: 10, c: 20, f: 5)]
        let picks = MealSuggester.suggestions(remaining: remaining, target: target, candidates: many, limit: 4)
        XCTAssertEqual(picks.count, 4)
        XCTAssertEqual(Set(picks.map { $0.name.lowercased() }).count, 4)
    }

    func testIgnoresZeroCalorieItems() {
        let remaining = MealSuggester.Macros(kcal: 500, protein: 40, carbs: 40, fat: 15)
        XCTAssertTrue(MealSuggester.suggestions(remaining: remaining, target: target,
                                                candidates: [food("Water", 0)]).isEmpty)
    }
}
