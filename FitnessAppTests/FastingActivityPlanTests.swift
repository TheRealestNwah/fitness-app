import XCTest
@testable import FitnessApp

final class FastingActivityPlanTests: XCTestCase {
    private let fast = FastingActivityPlan.Running(id: "a", start: Date(timeIntervalSince1970: 0), targetHours: 16)

    func testStartsActivityForNewFast() {
        XCTAssertEqual(FastingActivityPlan.changes(running: fast, showing: []), .init(start: fast, end: []))
    }

    func testLeavesExistingActivityAlone() {
        XCTAssertEqual(FastingActivityPlan.changes(running: fast, showing: ["a"]), .init(start: nil, end: []))
    }

    func testEndsActivitiesWhenNoFastIsRunning() {
        XCTAssertEqual(FastingActivityPlan.changes(running: nil, showing: ["a", "b"]), .init(start: nil, end: ["a", "b"]))
    }

    func testReplacesStaleActivities() {
        XCTAssertEqual(FastingActivityPlan.changes(running: fast, showing: ["old", "a"]), .init(start: nil, end: ["old"]))
        XCTAssertEqual(FastingActivityPlan.changes(running: fast, showing: ["old"]), .init(start: fast, end: ["old"]))
    }

    func testNothingToDoWhenIdle() {
        XCTAssertEqual(FastingActivityPlan.changes(running: nil, showing: []), .init(start: nil, end: []))
    }
}
