import XCTest
@testable import FitnessApp

final class ActivityTrendTests: XCTestCase {
    private func day(_ offset: Int, steps: Int, kcal: Double = 0) -> ActivityDay {
        ActivityDay(date: Date(timeIntervalSince1970: 1_700_000_000 + Double(offset) * 86_400), steps: steps, activeKcal: kcal)
    }

    func testProgressIsClampedAndZeroWithoutAGoal() {
        XCTAssertEqual(ActivityTrend.progress(steps: 5000, goal: 10_000), 0.5, accuracy: 0.001)
        XCTAssertEqual(ActivityTrend.progress(steps: 15_000, goal: 10_000), 1)
        XCTAssertEqual(ActivityTrend.progress(steps: 5000, goal: 0), 0)
    }

    func testGoalIsClamped() {
        XCTAssertEqual(ActivityTrend.clampedGoal(-5), 0)
        XCTAssertEqual(ActivityTrend.clampedGoal(80_000), ActivityTrend.maxStepGoal)
        XCTAssertEqual(ActivityTrend.clampedGoal(8000), 8000)
    }

    func testSummaryAveragesAndCountsDaysAtGoal() {
        let days = [day(0, steps: 12_000, kcal: 400), day(1, steps: 6000, kcal: 200), day(2, steps: 10_000, kcal: 300)]
        let summary = ActivityTrend.summary(days, goal: 10_000)
        XCTAssertEqual(summary.averageSteps, 9333)
        XCTAssertEqual(summary.averageActiveKcal, 300, accuracy: 0.001)
        XCTAssertEqual(summary.daysAtGoal, 2)
        XCTAssertEqual(summary.days, 3)
        XCTAssertEqual(summary.bestDay?.steps, 12_000)
    }

    func testDaysWithoutDataAreLeftOutOfAverages() {
        let days = [day(0, steps: 8000, kcal: 300), day(1, steps: 0), day(2, steps: 4000, kcal: 100)]
        let summary = ActivityTrend.summary(days, goal: 0)
        XCTAssertEqual(summary.averageSteps, 6000)
        XCTAssertEqual(summary.days, 2)
        XCTAssertNil(summary.daysAtGoal)
    }

    func testEmptySummary() {
        let summary = ActivityTrend.summary([], goal: 5000)
        XCTAssertEqual(summary.days, 0)
        XCTAssertEqual(summary.daysAtGoal, 0)
        XCTAssertNil(summary.bestDay)
    }
}
