import XCTest
@testable import FitnessApp

final class PhoneWorkoutTests: XCTestCase {
    func testShortRecordingsAreDiscarded() {
        XCTAssertFalse(PhoneWorkoutRules.shouldSave(seconds: 59))
        XCTAssertTrue(PhoneWorkoutRules.shouldSave(seconds: 60))
    }

    func testMinutesRoundAndNeverShowZero() {
        XCTAssertEqual(PhoneWorkoutRules.minutes(seconds: 61), 1)
        XCTAssertEqual(PhoneWorkoutRules.minutes(seconds: 29 * 60 + 40), 30)
    }

    func testMeasuredEnergyWinsOverEstimate() {
        XCTAssertEqual(PhoneWorkoutRules.calories(activeKcal: 212.4, kind: .running, weightKg: 70, seconds: 1800), 212)
    }

    func testEstimateWhenNothingMeasured() {
        // Running at 8 MET for 30 min at 70 kg: 7 × 70 × 0.5 = 245 kcal above resting.
        XCTAssertEqual(PhoneWorkoutRules.calories(activeKcal: 0, kind: .running, weightKg: 70, seconds: 1800), 245)
    }

    func testElapsedFormatting() {
        XCTAssertEqual(PhoneWorkoutRules.elapsedString(0), "0:00")
        XCTAssertEqual(PhoneWorkoutRules.elapsedString(245), "4:05")
        XCTAssertEqual(PhoneWorkoutRules.elapsedString(3723), "1:02:03")
        XCTAssertEqual(PhoneWorkoutRules.elapsedString(-5), "0:00")
    }

    func testLogNamesMatchTheHealthImporter() {
        XCTAssertEqual(PhoneWorkoutKind.walking.logName, "Walking")
        XCTAssertEqual(PhoneWorkoutKind.running.logName, "Running")
        XCTAssertEqual(PhoneWorkoutKind.cycling.logName, "Cycling")
        XCTAssertEqual(PhoneWorkoutKind.hiking.logName, "Hiking")
    }
}
