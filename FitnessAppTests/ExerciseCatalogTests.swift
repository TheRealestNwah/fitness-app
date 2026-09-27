import XCTest
@testable import FitnessApp

final class ExerciseCatalogTests: XCTestCase {
    func testNetCaloriesLeaveOutRestingBurn() {
        // Running at 8 MET for 30 min at 70 kg: 7 × 70 × 0.5 = 245 kcal above resting.
        XCTAssertEqual(ExerciseCatalog.netCalories(met: 8, weightKg: 70, minutes: 30), 245, accuracy: 0.001)
        XCTAssertEqual(ExerciseCatalog.netCalories(met: 0.8, weightKg: 70, minutes: 30), 0)
    }

    func testEarnBackShare() {
        XCTAssertEqual(ExerciseCatalog.earnBack(exerciseKcal: 300, percent: 50), 150)
        XCTAssertEqual(ExerciseCatalog.earnBack(exerciseKcal: 300, percent: 0), 0)
        XCTAssertEqual(ExerciseCatalog.earnBack(exerciseKcal: 300, percent: 100), 300)
    }

    func testHealthAndExerciseCreditsDontStack() {
        XCTAssertEqual(ExerciseCatalog.combinedCredit(health: 200, exercise: 150), 200)
        XCTAssertEqual(ExerciseCatalog.combinedCredit(health: 0, exercise: 150), 150)
    }

    func testCatalogNamesAreUnique() {
        XCTAssertEqual(Set(ExerciseCatalog.activities.map(\.name)).count, ExerciseCatalog.activities.count)
    }
}
