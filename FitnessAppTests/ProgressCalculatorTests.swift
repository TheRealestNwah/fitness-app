import XCTest
@testable import FitnessApp

final class ProgressCalculatorTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private lazy var today: Date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 30, hour: 12))!

    /// One weigh-in per day for `values`, the last one today.
    private func series(_ values: [Double]) -> [ProgressCalculator.WeightDay] {
        values.enumerated().map { index, kg in
            let date = calendar.date(byAdding: .day, value: index - (values.count - 1), to: today)!
            return ProgressCalculator.WeightDay(date: date, weightKg: kg)
        }
    }

    private func plateau(_ weights: [ProgressCalculator.WeightDay], goal: Double = 80,
                         target: Int = 2000, maintenance: MaintenanceEstimate? = nil) -> Plateau? {
        ProgressCalculator.plateau(weights: weights, goalKg: goal, currentTarget: target,
                                   maintenance: maintenance, weeklyLossKg: 0.5, sex: .male,
                                   today: today, calendar: calendar)
    }

    func testTrendAveragesTheLastSevenDays() {
        let weights = series([100, 100, 100, 90, 90, 90, 90, 90])
        let trend = ProgressCalculator.trend(on: today, weights: weights, calendar: calendar)
        XCTAssertEqual(trend ?? 0, (100 * 2 + 90 * 5) / 7, accuracy: 0.001)
    }

    func testMilestonesEveryFivePercent() {
        // 100 kg down to 88 kg in steady steps.
        let weights = series(stride(from: 100.0, through: 88.0, by: -0.2).map { $0 })
        let reached = ProgressCalculator.milestones(startKg: 100, weights: weights, calendar: calendar)
        XCTAssertEqual(reached.map(\.percent), [5, 10])
        XCTAssertEqual(reached[0].thresholdKg, 95, accuracy: 0.001)
        XCTAssertLessThan(reached[0].reachedOn, reached[1].reachedOn)
    }

    func testOneLightMorningIsNotAMilestone() {
        let weights = series([100, 100, 100, 100, 100, 100, 94])
        XCTAssertTrue(ProgressCalculator.milestones(startKg: 100, weights: weights, calendar: calendar).isEmpty)
    }

    func testNextMilestoneDistance() {
        let weights = series(Array(repeating: 96, count: 7))
        let next = ProgressCalculator.nextMilestone(startKg: 100, weights: weights, today: today, calendar: calendar)
        XCTAssertEqual(next?.percent, 5)
        XCTAssertEqual(next?.remainingKg ?? 0, 1, accuracy: 0.001)
    }

    func testRecentMilestoneOnlyShowsForAWeek() {
        let crossing = series(Array(repeating: 100, count: 7) + Array(repeating: 94, count: 7))
        XCTAssertEqual(ProgressCalculator.recentMilestone(startKg: 100, weights: crossing, today: today,
                                                          calendar: calendar)?.percent, 5)
        let old = series(Array(repeating: 100, count: 7) + Array(repeating: 94, count: 30))
        XCTAssertNil(ProgressCalculator.recentMilestone(startKg: 100, weights: old, today: today, calendar: calendar))
    }

    func testFlatTrendForTwoWeeksIsAPlateau() {
        let flat = series((0..<30).map { 90 + ($0 % 2 == 0 ? 0.1 : -0.1) })
        let result = plateau(flat)
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result?.days ?? 0, ProgressCalculator.plateauMinimumDays)
        XCTAssertFalse(result?.suggestions.isEmpty ?? true)
    }

    func testSteadyLossIsNotAPlateau() {
        XCTAssertNil(plateau(series(stride(from: 95.0, through: 89.0, by: -0.2).map { $0 })))
    }

    func testTooFewDaysIsNotAPlateau() {
        XCTAssertNil(plateau(series(Array(repeating: 90, count: 10))))
    }

    func testNoPlateauOnceTheGoalIsReached() {
        XCTAssertNil(plateau(series(Array(repeating: 79, count: 30)), goal: 80))
    }

    func testSparseWeighInsAreNotAPlateau() {
        let sparse = [0, -6, -12].map {
            ProgressCalculator.WeightDay(date: calendar.date(byAdding: .day, value: $0, to: today)!, weightKg: 90)
        }
        XCTAssertNil(plateau(sparse))
    }

    func testPlateauSuggestsTheAdaptiveTargetWhenItIsLower() {
        let estimate = MaintenanceEstimate(maintenanceKcal: 2400, meanIntakeKcal: 2000, weeklyWeightChangeKg: 0,
                                           daysLogged: 24, weighIns: 12, windowDays: 28, confidence: .high)
        let result = plateau(series(Array(repeating: 90, count: 30)), target: 2000, maintenance: estimate)
        XCTAssertTrue(result?.suggestions.first?.contains("1850 kcal") ?? false, "\(result?.suggestions ?? [])")
    }

    func testForecastFollowsTheActualRate() throws {
        // 0.1 kg a day for four weeks: 0.7 kg a week.
        let weights = series((0..<28).map { 90 - Double($0) * 0.1 })
        let forecast = try XCTUnwrap(ProgressCalculator.trendForecast(weights: weights, goalKg: 80,
                                                                      today: today, calendar: calendar))
        XCTAssertEqual(forecast.weeklyLossKg, 0.7, accuracy: 0.001)
        // The 7-day trend is 87.6 kg; 7.6 kg at 0.1 kg a day is 76 days.
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: forecast.goalDate).day
        XCTAssertEqual(days, 76)
    }

    func testNoForecastWhenFlatOrGaining() {
        let flat = series(Array(repeating: 85, count: 20))
        XCTAssertNil(ProgressCalculator.trendForecast(weights: flat, goalKg: 80, today: today, calendar: calendar))
        let gaining = series((0..<20).map { 85 + Double($0) * 0.05 })
        XCTAssertNil(ProgressCalculator.trendForecast(weights: gaining, goalKg: 80, today: today, calendar: calendar))
    }

    func testNoForecastWithoutEnoughHistory() {
        let week = series((0..<7).map { 90 - Double($0) * 0.2 })
        XCTAssertNil(ProgressCalculator.trendForecast(weights: week, goalKg: 80, today: today, calendar: calendar))
        let sparse = series((0..<20).map { 90 - Double($0) * 0.1 }).enumerated().filter { $0.offset % 5 == 0 }.map(\.element)
        XCTAssertNil(ProgressCalculator.trendForecast(weights: sparse, goalKg: 80, today: today, calendar: calendar))
    }

    func testNoForecastOnceTheGoalIsReached() {
        let weights = series((0..<20).map { 81 - Double($0) * 0.1 })
        XCTAssertNil(ProgressCalculator.trendForecast(weights: weights, goalKg: 80, today: today, calendar: calendar))
    }
}
