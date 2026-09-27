import XCTest
@testable import FitnessApp

final class BudgetCalculatorTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2                       // Monday
        return cal
    }()

    /// Monday 29 June 2026 plus `n` days, at noon.
    private func day(_ n: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 29 + n, hour: 12))!
    }

    private func intake(_ values: [Int: Double]) -> [Date: Double] {
        Dictionary(uniqueKeysWithValues: values.map { (calendar.startOfDay(for: day($0.key)), $0.value) })
    }

    func testLighterWeekdaysBankCaloriesForLater() {
        // Mon–Thu at 1500 against 2000 banks 2000 kcal for Fri–Sun.
        let target = BudgetCalculator.weeklyAdjustedTarget(dailyTarget: 2000, intakeByDay: intake([0: 1500, 1: 1500, 2: 1500, 3: 1500]),
                                                           floor: 1500, today: day(4), calendar: calendar)
        XCTAssertEqual(target, 2667)
        XCTAssertEqual(BudgetCalculator.weekBalance(dailyTarget: 2000, intakeByDay: intake([0: 1500, 1: 1500, 2: 1500, 3: 1500]),
                                                    today: day(4), calendar: calendar), 2000)
    }

    func testOverspendingLowersTheRestButNotBelowTheFloor() {
        let target = BudgetCalculator.weeklyAdjustedTarget(dailyTarget: 2000, intakeByDay: intake([0: 4000, 1: 4000, 2: 4000]),
                                                           floor: 1500, today: day(3), calendar: calendar)
        XCTAssertEqual(target, 1500)
    }

    func testUnloggedDaysCountAsOnTarget() {
        let target = BudgetCalculator.weeklyAdjustedTarget(dailyTarget: 2000, intakeByDay: [:],
                                                           floor: 1500, today: day(5), calendar: calendar)
        XCTAssertEqual(target, 2000)
    }

    func testBankingIsCapped() {
        let target = BudgetCalculator.weeklyAdjustedTarget(dailyTarget: 2000, intakeByDay: intake([0: 500, 1: 500, 2: 500, 3: 500, 4: 500, 5: 500]),
                                                           floor: 1500, today: day(6), calendar: calendar)
        XCTAssertEqual(target, 3000)
    }

    func testDietBreakWindowAndGoalDate() {
        XCTAssertTrue(BudgetCalculator.isOnBreak(start: day(0), end: day(14), on: day(3), calendar: calendar))
        XCTAssertFalse(BudgetCalculator.isOnBreak(start: day(0), end: day(14), on: day(14), calendar: calendar))
        XCTAssertFalse(BudgetCalculator.isOnBreak(start: nil, end: nil, on: day(3), calendar: calendar))

        let projected = day(60)
        // 10 break days still ahead on day 4 of a 14-day break.
        let moved = BudgetCalculator.goalDate(projected, breakStart: day(0), breakEnd: day(14), today: day(4), calendar: calendar)
        XCTAssertEqual(moved, calendar.date(byAdding: .day, value: 10, to: projected))
        XCTAssertEqual(BudgetCalculator.goalDate(projected, breakStart: nil, breakEnd: nil, calendar: calendar), projected)
    }
}
