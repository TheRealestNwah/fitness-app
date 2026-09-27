import XCTest
@testable import FitnessApp

final class FoodSearchRankingTests: XCTestCase {
    private typealias C = FoodSearchRanking.Candidate

    private func ranked(_ candidates: [C], _ query: String) -> [String] {
        FoodSearchRanking.rank(candidates, query: query) { $0 }.map(\.name)
    }

    func testNameMatchesOutrankOtherFields() {
        let result = ranked([C(name: "Granola bar", other: ["Oat Co"]),
                             C(name: "Oat milk"),
                             C(name: "Oats")], "oat")
        XCTAssertEqual(result, ["Oat milk", "Oats", "Granola bar"])
    }

    func testExactThenPrefixThenWordThenContains() {
        let result = ranked([C(name: "Coconut rice"), C(name: "Brown rice"), C(name: "Rice cakes"), C(name: "Rice")],
                            "rice")
        XCTAssertEqual(result, ["Rice", "Rice cakes", "Coconut rice", "Brown rice"])
    }

    func testFavouritesOutrankGenericFoodsOnNameMatches() {
        let result = ranked([C(name: "Chicken breast"), C(name: "Chicken curry", isFavorite: true)], "chicken")
        XCTAssertEqual(result, ["Chicken curry", "Chicken breast"])
    }

    func testRecentlyUsedBreaksTies() {
        let result = ranked([C(name: "Apple, red"), C(name: "Apple, green", lastUsed: .now.addingTimeInterval(-86_400))],
                            "apple")
        XCTAssertEqual(result, ["Apple, green", "Apple, red"])
        let stale = ranked([C(name: "Apple, red"), C(name: "Apple, green", lastUsed: .now.addingTimeInterval(-90 * 86_400))],
                           "apple")
        XCTAssertEqual(stale, ["Apple, red", "Apple, green"])
    }

    func testMealSlotMatchesSavedMeals() {
        // A saved meal's slot ("Lunch") is one of its other fields.
        let result = ranked([C(name: "Tuna salad", other: ["Lunch"]), C(name: "Oat bowl", other: ["Breakfast"])], "lunch")
        XCTAssertEqual(result, ["Tuna salad"])
    }

    func testNoMatchIsDropped() {
        XCTAssertNil(FoodSearchRanking.score(C(name: "Banana"), query: "kiwi"))
        XCTAssertEqual(ranked([C(name: "Banana")], "kiwi"), [])
    }
}
