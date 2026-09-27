import XCTest
@testable import FitnessApp

final class ServingUnitsTests: XCTestCase {
    func testReadsMetricServingSizes() {
        XCTAssertEqual(ServingUnits.metricPerServing("100 g"), GroceryAggregator.Quantity(value: 100, unit: "g"))
        XCTAssertEqual(ServingUnits.metricPerServing("1 slice (43 g)"), GroceryAggregator.Quantity(value: 43, unit: "g"))
        XCTAssertEqual(ServingUnits.metricPerServing("1 cup (240 ml)"), GroceryAggregator.Quantity(value: 240, unit: "ml"))
        XCTAssertEqual(ServingUnits.metricPerServing("0.5 kg"), GroceryAggregator.Quantity(value: 500, unit: "g"))
    }

    func testNoMetricForHouseholdOnlyDescriptions() {
        XCTAssertNil(ServingUnits.metricPerServing("1 medium"))
        XCTAssertNil(ServingUnits.metricPerServing("handful"))
        XCTAssertNil(ServingUnits.metricPerServing("1 serving"))
    }

    func testConvertsBetweenGramsAndServings() {
        let slice = GroceryAggregator.Quantity(value: 40, unit: "g")
        XCTAssertEqual(ServingUnits.servings(forMetric: 100, per: slice), 2.5, accuracy: 0.001)
        XCTAssertEqual(ServingUnits.metric(forServings: 1.5, per: slice), 60, accuracy: 0.001)
    }
}
