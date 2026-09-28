import XCTest
@testable import FitnessApp

final class FoodSentenceParserTests: XCTestCase {
    private typealias Item = FoodSentenceParser.Item

    func testSplitsASentenceIntoItems() {
        XCTAssertEqual(FoodSentenceParser.parse("2 eggs, a slice of whole wheat toast and a black coffee"), [
            Item(quantity: 2, unit: nil, name: "eggs"),
            Item(quantity: 1, unit: "slice", name: "whole wheat toast"),
            Item(quantity: 1, unit: nil, name: "black coffee"),
        ])
    }

    func testOtherSeparators() {
        XCTAssertEqual(FoodSentenceParser.split("Oatmeal with blueberries; banana + tea & honey\ntoast."),
                       ["oatmeal", "blueberries", "banana", "tea", "honey", "toast"])
    }

    func testQuantitiesAndUnits() {
        XCTAssertEqual(FoodSentenceParser.parseItem("150g chicken breast"), Item(quantity: 150, unit: "g", name: "chicken breast"))
        XCTAssertEqual(FoodSentenceParser.parseItem("1/2 cup of oats"), Item(quantity: 0.5, unit: "cup", name: "oats"))
        XCTAssertEqual(FoodSentenceParser.parseItem("1 1/2 cups rice"), Item(quantity: 1.5, unit: "cup", name: "rice"))
        XCTAssertEqual(FoodSentenceParser.parseItem("1.5 cups rice"), Item(quantity: 1.5, unit: "cup", name: "rice"))
        XCTAssertEqual(FoodSentenceParser.parseItem("two slices of pizza"), Item(quantity: 2, unit: "slice", name: "pizza"))
        XCTAssertEqual(FoodSentenceParser.parseItem("half an avocado"), Item(quantity: 0.5, unit: nil, name: "avocado"))
        XCTAssertEqual(FoodSentenceParser.parseItem("a couple of eggs"), Item(quantity: 2, unit: nil, name: "eggs"))
        XCTAssertEqual(FoodSentenceParser.parseItem("a glass of milk"), Item(quantity: 1, unit: "glass", name: "milk"))
        XCTAssertEqual(FoodSentenceParser.parseItem("banana"), Item(quantity: 1, unit: nil, name: "banana"))
        XCTAssertEqual(FoodSentenceParser.parseItem("0.5 kg potatoes"), Item(quantity: 500, unit: "g", name: "potatoes"))
        XCTAssertEqual(FoodSentenceParser.parseItem("2 oz cheddar")?.quantity ?? 0, 56.7, accuracy: 0.01)
        XCTAssertNil(FoodSentenceParser.parseItem("a"))
    }

    func testServingsFromTheFoodsServingDescription() {
        let servings = { (item: Item, description: String) in
            FoodSentenceParser.servings(for: item, servingDescription: description)
        }
        XCTAssertEqual(servings(Item(quantity: 2, unit: nil, name: "eggs"), "1 egg (50 g)"), 2)
        XCTAssertEqual(servings(Item(quantity: 150, unit: "g", name: "chicken"), "100 g"), 1.5)
        XCTAssertEqual(servings(Item(quantity: 240, unit: "ml", name: "coffee"), "1 cup (240 ml)"), 1)
        XCTAssertEqual(servings(Item(quantity: 0.5, unit: "cup", name: "oats"), "1 cup (80 g)"), 0.5)
        XCTAssertEqual(servings(Item(quantity: 2, unit: "slice", name: "bread"), "2 slices (86 g)"), 1)
        // A unit the food doesn't describe counts servings.
        XCTAssertEqual(servings(Item(quantity: 2, unit: "bowl", name: "soup"), "1 cup (240 ml)"), 2)
    }

    func testServingsFromAPreset() {
        let presets = [ServingPreset(label: "1 slice", servings: 0.125)]
        XCTAssertEqual(FoodSentenceParser.servings(for: Item(quantity: 2, unit: "slice", name: "pizza"),
                                                   servingDescription: "1 pizza", presets: presets), 0.25)
    }

    func testMatchesSavedFoods() {
        let foods = ["Egg, large", "Whole wheat bread", "White bread", "Coffee, black", "Black beans", "Banana"]
        let match = { (name: String) in
            FoodSentenceParser.bestMatch(name, in: foods) { FoodSearchRanking.Candidate(name: $0) }
        }
        XCTAssertEqual(match("eggs"), "Egg, large")
        XCTAssertEqual(match("black coffee"), "Coffee, black")
        XCTAssertEqual(match("whole wheat toast"), "Whole wheat bread")
        XCTAssertEqual(match("bananas"), "Banana")
        XCTAssertNil(match("sushi"))
    }
}
