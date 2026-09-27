import XCTest
@testable import FitnessApp

final class BackgroundRefreshTests: XCTestCase {
    private let calendar = Calendar.current

    private func today(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date(timeIntervalSince1970: 1_800_000_000))!
    }

    func testRegularIntervalDuringTheDay() {
        let now = today(9)
        XCTAssertEqual(BackgroundRefresh.earliestBegin(after: now), now.addingTimeInterval(3 * 3600))
    }

    func testJustAfterMidnightWhenThatComesSooner() {
        let now = today(22, 30)
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        XCTAssertEqual(BackgroundRefresh.earliestBegin(after: now), midnight.addingTimeInterval(5 * 60))
    }

    func testRightAfterMidnightWaitsTheRegularInterval() {
        let now = today(0, 10)
        XCTAssertEqual(BackgroundRefresh.earliestBegin(after: now), now.addingTimeInterval(3 * 3600))
    }

    func testAlwaysInTheFuture() {
        for hour in 0..<24 {
            let now = today(hour, 59)
            XCTAssertGreaterThan(BackgroundRefresh.earliestBegin(after: now), now, "\(hour):59")
        }
    }
}
