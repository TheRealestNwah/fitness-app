import XCTest
@testable import FitnessApp

final class GlucoseUnitTests: XCTestCase {
    func testConvertsBothWays() {
        XCTAssertEqual(GlucoseUnit.mmolL.value(mgdL: 90), 5, accuracy: 0.0001)
        XCTAssertEqual(GlucoseUnit.mmolL.mgdL(from: 5.5), 99, accuracy: 0.0001)
        XCTAssertEqual(GlucoseUnit.mgdL.value(mgdL: 90), 90)
    }

    func testFormatting() {
        XCTAssertEqual(GlucoseUnit.mgdL.string(mgdL: 94.6), "95 mg/dL")
        XCTAssertEqual(GlucoseUnit.mmolL.string(mgdL: 95), "5.3 mmol/L")
    }

    func testRegionDefaults() {
        XCTAssertEqual(GlucoseUnit.regionDefault("US"), .mgdL)
        XCTAssertEqual(GlucoseUnit.regionDefault("GB"), .mmolL)
        XCTAssertEqual(GlucoseUnit.regionDefault(nil), .mgdL)
    }
}
