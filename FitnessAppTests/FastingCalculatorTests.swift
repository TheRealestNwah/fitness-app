import XCTest
@testable import FitnessApp

final class FastingCalculatorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_780_000_000)

    private func fast(hours: Double?, target: Double = 16) -> FastingCalculator.Fast {
        .init(start: start, end: hours.map { start.addingTimeInterval($0 * 3600) }, targetHours: target)
    }

    func testProgressWhileActive() {
        let active = fast(hours: nil)
        XCTAssertEqual(FastingCalculator.progress(active, now: start.addingTimeInterval(8 * 3600)), 0.5, accuracy: 0.001)
        XCTAssertEqual(FastingCalculator.elapsedHours(active, now: start.addingTimeInterval(4 * 3600)), 4, accuracy: 0.001)
    }

    func testCompleteOnlyOnceTheTargetIsReached() {
        XCTAssertTrue(FastingCalculator.isComplete(fast(hours: 16)))
        XCTAssertTrue(FastingCalculator.isComplete(fast(hours: 17.5)))
        XCTAssertFalse(FastingCalculator.isComplete(fast(hours: 12)))
        XCTAssertFalse(FastingCalculator.isComplete(fast(hours: nil)))
    }

    func testCompletedCountsWithinTheWindow() {
        let fasts = [fast(hours: 16), fast(hours: 10), fast(hours: 20, target: 18), fast(hours: nil)]
        let window = (start, start.addingTimeInterval(7 * 86_400))
        XCTAssertEqual(FastingCalculator.completed(fasts, from: window.0, to: window.1), 2)
        XCTAssertEqual(FastingCalculator.completed(fasts, from: window.1, to: window.1.addingTimeInterval(86_400)), 0)
    }

    func testWeeklyReviewReportsCompletedFasts() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let today = cal.date(from: DateComponents(year: 2026, month: 6, day: 30, hour: 12))!
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!
        let fasts = [FastingCalculator.Fast(start: twoDaysAgo, end: twoDaysAgo.addingTimeInterval(16 * 3600), targetHours: 16)]
        let review = WeeklyReviewCalculator.review(foodLogs: [], weights: [], budget: 1800, plannedWeeklyLossKg: 0.5,
                                                   fasts: fasts, today: today, calendar: cal)
        XCTAssertEqual(review.completedFasts, 1)
        XCTAssertTrue(review.hasContent)
    }
}
