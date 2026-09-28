import XCTest
@testable import FitnessApp

final class DateLabelTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testShortLabelOmitsTheCurrentYear() {
        let now = date(2026, 9, 28)
        XCTAssertFalse(date(2026, 10, 30).shortDateLabel(relativeTo: now).contains("2026"))
        XCTAssertFalse(date(2026, 10, 30).longDateLabel(relativeTo: now).contains("2026"))
    }

    func testFarOffGoalShowsItsYear() {
        // 120 lb at 0.5 kg/week lands about two years out; "Oct 30" alone reads as next month.
        let now = date(2026, 9, 28)
        XCTAssertTrue(date(2028, 10, 30).shortDateLabel(relativeTo: now).contains("2028"))
        XCTAssertTrue(date(2028, 10, 30).longDateLabel(relativeTo: now).contains("2028"))
    }

    func testDatesAcrossNewYearShowTheYear() {
        let now = date(2026, 12, 30)
        XCTAssertTrue(date(2027, 1, 4).shortDateLabel(relativeTo: now).contains("2027"))
        XCTAssertTrue(date(2025, 12, 29).shortDateLabel(relativeTo: date(2026, 1, 2)).contains("2025"))
    }
}
