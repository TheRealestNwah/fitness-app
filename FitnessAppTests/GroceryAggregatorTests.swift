import XCTest
@testable import FitnessApp

private typealias Q = GroceryAggregator.Quantity

final class GroceryAggregatorTests: XCTestCase {
    func testParsePrefersMetricInBrackets() {
        XCTAssertEqual(GroceryAggregator.parse("1/2 cup (40 g)"), Q(value: 40, unit: "g"))
        XCTAssertEqual(GroceryAggregator.parse("1 cup (240 ml)"), Q(value: 240, unit: "ml"))
    }

    func testParseLeadingQuantity() {
        XCTAssertEqual(GroceryAggregator.parse("120 g"), Q(value: 120, unit: "g"))
        XCTAssertEqual(GroceryAggregator.parse("2 large"), Q(value: 2, unit: "large"))
        XCTAssertEqual(GroceryAggregator.parse("1/2 cup"), Q(value: 0.5, unit: "cup"))
        XCTAssertEqual(GroceryAggregator.parse("1 1/2 cups"), Q(value: 1.5, unit: "cups"))
        XCTAssertEqual(GroceryAggregator.parse("1.5 kg"), Q(value: 1500, unit: "g"))
        XCTAssertNil(GroceryAggregator.parse("handful"))
    }

    func testCombineSumsSameUnit() {
        let result = GroceryAggregator.combine([("1 tsp (5 g)", 1), ("1 tbsp (14 g)", 1)])
        XCTAssertEqual(result, ["19 g"])
    }

    func testCombineAppliesMultiplier() {
        let result = GroceryAggregator.combine([("2 large", 1), ("2 large", 0.5)])
        XCTAssertEqual(result, ["3 large"])
    }

    func testCombineTreatsPluralUnitsAsOne() {
        let result = GroceryAggregator.combine([("1 slice", 1), ("2 slices", 1)])
        XCTAssertEqual(result, ["3 slices"])
    }

    func testCombineListsMismatchedUnitsSeparately() {
        let result = GroceryAggregator.combine([("120 g", 1), ("2 large", 1), ("handful", 1), ("handful", 1)])
        XCTAssertEqual(result, ["120 g", "2 large", "handful"])
    }

    func testCombineKeepsUnparsedAmountWithMultiplier() {
        XCTAssertEqual(GroceryAggregator.combine([("handful", 0.5)]), ["handful × 0.5"])
    }

    func testDisplayRoundsMetricAndTrimsDecimals() {
        XCTAssertEqual(GroceryAggregator.display(Q(value: 59.6, unit: "g")), "60 g")
        XCTAssertEqual(GroceryAggregator.display(Q(value: 0.5, unit: "cup")), "0.5 cup")
        XCTAssertEqual(GroceryAggregator.display(Q(value: 1.5, unit: "cup")), "1.5 cups")
        XCTAssertEqual(GroceryAggregator.display(Q(value: 2, unit: "tbsp")), "2 tbsp")
    }

    func testKeepsUnitsItDoesNotKnowAsWritten() {
        XCTAssertEqual(GroceryAggregator.display(Q(value: 4, unit: "Zehen")), "4 Zehen")
        XCTAssertEqual(GroceryAggregator.display(Q(value: 2, unit: "diente")), "2 diente")
        XCTAssertEqual(GroceryAggregator.display(Q(value: 3, unit: "tbsp")), "3 tbsp")
        XCTAssertEqual(GroceryAggregator.display(Q(value: 2, unit: "clove")), "2 cloves")
    }
}
