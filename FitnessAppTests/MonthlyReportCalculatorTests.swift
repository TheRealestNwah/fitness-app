import XCTest
@testable import FitnessApp

final class MonthlyReportCalculatorTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 8))!
    }

    private func report(today: Date, food: [Date] = [], weights: [(Date, Double)] = []) -> MonthlyReport? {
        MonthlyReportCalculator.report(month: day(6, 15),
                                       foodLogs: food.map { .init(date: $0, calories: 1800) },
                                       weights: weights.map { .init(date: $0.0, weightKg: $0.1) },
                                       budget: 1900, workoutDates: [day(6, 3), day(7, 1)],
                                       today: today, calendar: calendar)
    }

    func testTrendChangeAndBestWeekOverAFullMonth() throws {
        // Steady 0.1 kg a day loss through June, with a faster week from the 8th.
        var weights: [(Date, Double)] = []
        var kg = 90.0
        for d in 1...30 {
            kg -= (8...14).contains(d) ? 0.3 : 0.1
            weights.append((day(6, d), kg))
        }
        let r = try XCTUnwrap(report(today: day(7, 5), weights: weights))
        XCTAssertTrue(r.isComplete)
        XCTAssertEqual(r.daysSoFar, 30)
        XCTAssertLessThan(try XCTUnwrap(r.changeKg), -3.5)
        let best = try XCTUnwrap(r.bestWeek)
        XCTAssertEqual(calendar.component(.day, from: best.start), 8)
        XCTAssertEqual(r.workouts, 1, "July's workout isn't counted")
    }

    func testLoggingDaysAndLongestRunSoFar() throws {
        let food = [1, 2, 3, 5, 6, 10].map { day(6, $0) } + [day(6, 10)]
        let r = try XCTUnwrap(report(today: day(6, 12), food: food))
        XCTAssertFalse(r.isComplete)
        XCTAssertEqual(r.daysSoFar, 12)
        XCTAssertEqual(r.daysLogged, 6)
        XCTAssertEqual(r.longestStreak, 3)
        XCTAssertEqual(try XCTUnwrap(r.averageIntake), 1800 * 7 / 6, accuracy: 0.01)
        XCTAssertNil(r.changeKg)
    }

    func testFutureMonthHasNoReport() {
        XCTAssertNil(report(today: day(5, 20)))
    }

    func testDefaultsToLastMonthInTheFirstWeek() {
        XCTAssertEqual(calendar.component(.month, from: MonthlyReportView.defaultMonth(today: day(7, 3), calendar: calendar)), 6)
        XCTAssertEqual(calendar.component(.month, from: MonthlyReportView.defaultMonth(today: day(7, 12), calendar: calendar)), 7)
    }
}
