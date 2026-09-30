import XCTest
@testable import FitnessApp

final class PhotoFoodSuggesterTests: XCTestCase {
    private let foods = [
        FoodItem(name: "Pizza, cheese", servingDescription: "1 slice (107 g)", calories: 285, protein: 12, carbs: 36, fat: 10),
        FoodItem(name: "French fries", servingDescription: "1 medium (117 g)", calories: 365, protein: 4, carbs: 48, fat: 17),
        FoodItem(name: "Egg", servingDescription: "1 large (50 g)", calories: 72, protein: 6.3, carbs: 0.4, fat: 4.8),
    ]

    func testCandidatesAreConfidentSpecificAndClean() {
        let labels: [(label: String, confidence: Float)] = [
            ("food", 0.95), ("french_fries", 0.6), ("pizza", 0.8), ("tableware", 0.7), ("sushi", 0.05), ("pizza", 0.3),
        ]
        XCTAssertEqual(PhotoFoodSuggester.candidates(labels), ["pizza", "french fries"])
    }

    func testSuggestionsMatchSavedFoodsOncePerFood() {
        let suggestions = PhotoFoodSuggester.suggestions(for: ["2 slices pizza", "pizza", "french fries", "kimchi"], foods: foods)
        XCTAssertEqual(suggestions.map(\.food.name), ["Pizza, cheese", "French fries"])
        XCTAssertEqual(suggestions.first?.servings, 2)
        XCTAssertEqual(suggestions.first?.source, "2 slices pizza")
    }

    func testSuggestionsAreLimited() {
        let suggestions = PhotoFoodSuggester.suggestions(for: ["pizza", "french fries", "egg"], foods: foods, limit: 2)
        XCTAssertEqual(suggestions.count, 2)
    }
}
