import XCTest
@testable import FitnessApp

final class CycleCalculatorTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    func testPeriodStartsAreTheFirstFlowDays() {
        let flow = [day(3, 1), day(3, 2), day(3, 3), day(3, 29), day(3, 30), day(4, 1)]
        // April 1 is two days after March 30 (March has 31 days), so it's the same period.
        XCTAssertEqual(CycleCalculator.periodStarts(flowDays: flow, calendar: calendar), [day(3, 1), day(3, 29)])
    }

    func testAverageCycleIgnoresImplausibleGaps() {
        XCTAssertEqual(CycleCalculator.averageCycleDays([day(1, 1), day(1, 29), day(2, 28)], calendar: calendar), 29)
        XCTAssertNil(CycleCalculator.averageCycleDays([day(1, 1), day(3, 20)], calendar: calendar))
    }

    func testRetentionWindowAroundEachPeriodAndTheNextOne() {
        let starts = [day(3, 1), day(3, 29)]
        let days = CycleCalculator.retentionDays(periodStarts: starts, today: day(4, 24), calendar: calendar)
        XCTAssertTrue(days.contains(day(2, 24)))          // 5 days before March 1
        XCTAssertTrue(days.contains(day(3, 3)))           // 2 days after
        XCTAssertFalse(days.contains(day(3, 4)))
        // Next period expected on April 26 (28-day cycle): the window has started but stops at today.
        XCTAssertTrue(days.contains(day(4, 21)))
        XCTAssertFalse(days.contains(day(4, 25)))
    }

    func testExcludingRetentionKeepsEnoughData() {
        let weights = (1...10).map { WeeklyReviewCalculator.WeightDay(date: day(5, $0), weightKg: 80) }
        let few: Set<Date> = [day(5, 2), day(5, 3)]
        XCTAssertEqual(CycleCalculator.excludingRetention(weights, days: few, calendar: calendar).count, 8)
        let most = Set((1...8).map { day(5, $0) })
        XCTAssertEqual(CycleCalculator.excludingRetention(weights, days: most, calendar: calendar).count, 10)
    }
}
