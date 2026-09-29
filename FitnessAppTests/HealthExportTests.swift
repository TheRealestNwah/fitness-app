import HealthKit
import XCTest
@testable import FitnessApp

final class HealthExportTests: XCTestCase {
    func testAlwaysWritesEnergyAndMacros() {
        let values = HealthImportRules.dietaryValues(calories: 400, protein: 20, carbs: 50, fat: 10,
                                                     fiber: 0, sugar: 0, sodiumMg: 0)
        XCTAssertEqual(values.map(\.type), [.dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal])
        XCTAssertEqual(values.map(\.value), [400, 20, 50, 10])
    }

    func testWritesRecordedMicronutrientsInTheirUnits() {
        let values = HealthImportRules.dietaryValues(calories: 400, protein: 20, carbs: 50, fat: 10,
                                                     fiber: 6, sugar: 12, sodiumMg: 480)
        let byType = Dictionary(uniqueKeysWithValues: values.map { ($0.type, $0) })
        XCTAssertEqual(byType[.dietaryFiber]?.value, 6)
        XCTAssertEqual(byType[.dietaryFiber]?.unit, .gram())
        XCTAssertEqual(byType[.dietarySugar]?.value, 12)
        XCTAssertEqual(byType[.dietarySodium]?.value, 480)
        XCTAssertEqual(byType[.dietarySodium]?.unit, .gramUnit(with: .milli))
    }

    func testClampsNegativeMacrosToZero() {
        let values = HealthImportRules.dietaryValues(calories: -5, protein: -1, carbs: 0, fat: 0,
                                                     fiber: -2, sugar: 0, sodiumMg: 0)
        XCTAssertEqual(values.count, 4)
        XCTAssertTrue(values.allSatisfy { $0.value >= 0 })
    }

    func testEveryWrittenTypeIsDeletable() {
        let written = HealthImportRules.dietaryValues(calories: 1, protein: 1, carbs: 1, fat: 1,
                                                      fiber: 1, sugar: 1, sodiumMg: 1).map(\.type)
        XCTAssertEqual(Set(written), Set(HealthImportRules.dietaryTypes))
    }

    func testProfileDetailsMapSexForTheCalorieFormula() {
        XCTAssertEqual(HealthProfileDetails.sex(.female), .female)
        XCTAssertEqual(HealthProfileDetails.sex(.male), .male)
        XCTAssertNil(HealthProfileDetails.sex(.other))
        XCTAssertNil(HealthProfileDetails.sex(.notSet))
        XCTAssertTrue(HealthProfileDetails().isEmpty)
        XCTAssertFalse(HealthProfileDetails(heightCm: 170).isEmpty)
    }
}
