import XCTest
@testable import FitnessApp

final class MaintenanceCalculatorTests: XCTestCase {
    func testInsideTheBand() {
        XCTAssertEqual(MaintenanceCalculator.status(trendKg: 70.9, centerKg: 70, bandKg: 1.5), .inBand)
        XCTAssertEqual(MaintenanceCalculator.status(trendKg: 71.5, centerKg: 70, bandKg: 1.5), .inBand)   // edge counts
        XCTAssertEqual(MaintenanceCalculator.status(trendKg: 68.5, centerKg: 70, bandKg: 1.5), .inBand)
    }

    func testOutsideTheBandReportsTheDistance() {
        guard case .above(let over) = MaintenanceCalculator.status(trendKg: 72.1, centerKg: 70, bandKg: 1.5) else {
            return XCTFail("expected above")
        }
        XCTAssertEqual(over, 0.6, accuracy: 0.001)
        guard case .below(let under) = MaintenanceCalculator.status(trendKg: 68.0, centerKg: 70, bandKg: 1.5) else {
            return XCTFail("expected below")
        }
        XCTAssertEqual(under, 0.5, accuracy: 0.001)
        XCTAssertTrue(MaintenanceCalculator.status(trendKg: 68.0, centerKg: 70, bandKg: 1.5).isOutside)
    }

    func testPositionAcrossTheBand() {
        XCTAssertEqual(MaintenanceCalculator.position(trendKg: 70, centerKg: 70, bandKg: 1.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(MaintenanceCalculator.position(trendKg: 68.5, centerKg: 70, bandKg: 1.5), 0, accuracy: 0.001)
        XCTAssertEqual(MaintenanceCalculator.position(trendKg: 75, centerKg: 70, bandKg: 1.5), 1, accuracy: 0.001)
    }

    func testOfferedOnlyOnceTheTrendReachesGoal() {
        XCTAssertTrue(MaintenanceCalculator.shouldOffer(trendKg: 69.9, goalKg: 70, isMaintaining: false))
        XCTAssertFalse(MaintenanceCalculator.shouldOffer(trendKg: 70.4, goalKg: 70, isMaintaining: false))
        XCTAssertFalse(MaintenanceCalculator.shouldOffer(trendKg: 69.9, goalKg: 70, isMaintaining: true))
        XCTAssertFalse(MaintenanceCalculator.shouldOffer(trendKg: nil, goalKg: 70, isMaintaining: false))
    }

    func testTargetIsMaintenanceAboveTheFloor() {
        XCTAssertEqual(MaintenanceCalculator.calorieTarget(tdee: 2400, sex: .male), 2400)
        XCTAssertEqual(MaintenanceCalculator.calorieTarget(tdee: 1100, sex: .female), 1200)
    }
}
