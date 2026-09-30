import XCTest
@testable import FitnessApp

final class TrendReadinessTests: XCTestCase {
    private let today = Calendar.current.startOfDay(for: .now).addingTimeInterval(12 * 3600)

    private func weighIns(daysAgo: [Int]) -> [WeeklyReviewCalculator.WeightDay] {
        daysAgo.map { WeeklyReviewCalculator.WeightDay(date: today.adding(days: -$0), weightKg: 80) }
    }

    func testNothingYet() {
        let progress = TrendReadiness.forecast(weights: [], today: today)
        XCTAssertFalse(progress.isReady)
        XCTAssertEqual(progress.fraction, 0)
        XCTAssertEqual(progress.summary, "0 of \(ProgressCalculator.forecastMinimumWeighIns) weigh-ins, spread over 0 of \(ProgressCalculator.forecastMinimumSpanDays) days")
    }

    func testForecastCountsWeighInsAndSpan() {
        let progress = TrendReadiness.forecast(weights: weighIns(daysAgo: [0, 2, 5]), today: today)
        XCTAssertEqual(progress.weighIns, 3)
        XCTAssertEqual(progress.spanDays, 6)
        XCTAssertFalse(progress.isReady)
        XCTAssertTrue(progress.needsWeighIns)
    }

    func testForecastReadyMatchesTheCalculatorThreshold() {
        // Five weigh-ins over exactly fourteen days, the forecast's minimum.
        let progress = TrendReadiness.forecast(weights: weighIns(daysAgo: [0, 3, 7, 10, 13]), today: today)
        XCTAssertTrue(progress.isReady)
        XCTAssertEqual(progress.fraction, 1)
        XCTAssertEqual(progress.summary, "")
    }

    func testOldWeighInsAreIgnored() {
        let progress = TrendReadiness.rate(weights: weighIns(daysAgo: [0, 40, 50]), today: today)
        XCTAssertEqual(progress.weighIns, 1)
        XCTAssertEqual(progress.spanDays, 1)
    }

    func testRateOnlyMissingSpan() {
        let progress = TrendReadiness.rate(weights: weighIns(daysAgo: [0, 1, 2]), today: today)
        XCTAssertEqual(progress.missing, ["spread over 3 of 7 days"])
        XCTAssertEqual(progress.summary, "Spread over 3 of 7 days")
    }

    func testMaintenanceCountsLoggedDaysBeforeToday() {
        let food = (0..<10).map { WeeklyReviewCalculator.FoodDay(date: today.adding(days: -$0), calories: 1800) }
        let progress = TrendReadiness.maintenance(foodLogs: food, weights: weighIns(daysAgo: [1, 8, 15, 20]), today: today)
        XCTAssertEqual(progress.daysLogged, 9)
        XCTAssertEqual(progress.weighIns, 4)
        XCTAssertFalse(progress.isReady)
        XCTAssertFalse(progress.needsWeighIns)
        XCTAssertEqual(progress.missing, ["9 of \(AdaptiveTargetCalculator.minimumDaysLogged) days of food logged"])
    }
}
