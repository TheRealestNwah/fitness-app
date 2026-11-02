import XCTest
@testable import FitnessApp

final class UnitSystemDefaultTests: XCTestCase {
    func testImperialWhereTheRegionMeasuresTheUSOrUKWay() {
        XCTAssertEqual(UnitSystem.preferred(for: Locale(identifier: "en_US")), .imperial)
        XCTAssertEqual(UnitSystem.preferred(for: Locale(identifier: "en_GB")), .imperial)
        XCTAssertEqual(UnitSystem.preferred(for: Locale(identifier: "es_US")), .imperial)
    }

    func testMetricEverywhereElse() {
        for identifier in ["de_DE", "en_AU", "en_CA", "fr_FR", "ja_JP", "en_IE"] {
            XCTAssertEqual(UnitSystem.preferred(for: Locale(identifier: identifier)), .metric, identifier)
        }
    }

    func testDefaultsToTheCurrentLocale() {
        XCTAssertEqual(UnitSystem.preferred(), UnitSystem.preferred(for: .current))
    }
}
