import XCTest
@testable import FitnessApp

final class WeightProgressTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private lazy var today: Date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 30, hour: 12))!

    private func makeProfile(start: Double = 100, goal: Double = 85) -> UserProfile {
        UserProfile(name: "T", sex: .male, birthDate: Date(timeIntervalSince1970: 0), heightCm: 185,
                    startWeightKg: start, goalWeightKg: goal, activityLevel: .moderate, weeklyLossKg: 0.5,
                    unitSystem: .metric)
    }

    /// One weigh-in per day for `values`, the last one today.
    private func series(_ values: [Double]) -> [WeightProgress.WeightDay] {
        values.enumerated().map { index, kg in
            WeightProgress.WeightDay(date: date(daysAgo: values.count - 1 - index), weightKg: kg)
        }
    }

    private func date(daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: today)!
    }

    private func progress(_ profile: UserProfile, _ weighIns: [WeightProgress.WeightDay],
                          food: [WeightProgress.FoodDay] = [], retention: Set<Date> = []) -> WeightProgress {
        WeightProgress(profile: profile, weighIns: weighIns, food: food, retentionDays: retention,
                       now: today, calendar: calendar)
    }

    // MARK: Lost and remaining

    func testCurrentWeightIsTheLatestWeighInInAnyOrder() {
        let weighIns = series([98, 97, 96]).reversed()
        let result = progress(makeProfile(), Array(weighIns))

        XCTAssertEqual(result.currentKg, 96)
        XCTAssertEqual(result.lostKg, 4, accuracy: 0.001)
        XCTAssertEqual(result.remainingKg, 11, accuracy: 0.001)
        XCTAssertEqual(result.goalFraction, 4.0 / 15.0, accuracy: 0.001)
        XCTAssertFalse(result.goalReached)
    }

    func testStartingWeightBeforeAnyWeighIn() {
        let result = progress(makeProfile(), [])

        XCTAssertEqual(result.currentKg, 100)
        XCTAssertEqual(result.lostKg, 0)
        XCTAssertEqual(result.goalFraction, 0)
        XCTAssertNil(result.trendKg)
    }

    func testPastTheGoalLeavesNothingRemaining() {
        let result = progress(makeProfile(), series([84]))

        XCTAssertEqual(result.remainingKg, 0)
        XCTAssertTrue(result.goalReached)
        XCTAssertEqual(result.goalFraction, 1)
        XCTAssertNil(result.plannedGoalDate)
    }

    func testGainingShowsANegativeLossAndNoProgress() {
        let result = progress(makeProfile(), series([102]))

        XCTAssertEqual(result.lostKg, -2, accuracy: 0.001)
        XCTAssertEqual(result.goalFraction, 0)
    }

    // MARK: Rate and forecast

    func testNoRateUntilThereAreEnoughWeighIns() {
        let result = progress(makeProfile(), series([97, 96.8]))

        XCTAssertFalse(result.rateReadiness.isReady)
        XCTAssertNil(result.weeklyChangeKg)
    }

    func testRateIsNegativeWhileLosing() throws {
        // 0.1 kg a day for four weeks: 0.7 kg a week.
        let result = progress(makeProfile(), series((0..<28).map { 98 - Double($0) * 0.1 }))

        let rate = try XCTUnwrap(result.weeklyChangeKg)
        XCTAssertEqual(rate, -0.7, accuracy: 0.01)
        let forecast = try XCTUnwrap(result.forecast)
        XCTAssertEqual(forecast.weeklyLossKg, 0.7, accuracy: 0.01)
    }

    func testRetentionDaysAreLeftOutOfTheTrendChecksOnly() {
        let weighIns = series((0..<10).map { 98 - Double($0) * 0.1 })
        let retention: Set<Date> = [calendar.startOfDay(for: date(daysAgo: 1)), calendar.startOfDay(for: date(daysAgo: 2))]
        let result = progress(makeProfile(), weighIns, retention: retention)

        XCTAssertEqual(result.weighIns.count, 10)
        XCTAssertEqual(result.trendWeighIns.count, 8)
        XCTAssertEqual(result.forecastReadiness.weighIns, 8)
        XCTAssertEqual(result.rateReadiness.weighIns, 10)
    }

    func testPlannedGoalDateMovesLaterByADietBreakAhead() throws {
        let profile = makeProfile()
        let without = try XCTUnwrap(progress(profile, series([96])).plannedGoalDate)

        profile.dietBreakStart = date(daysAgo: -10)
        profile.dietBreakEnd = date(daysAgo: -24)
        let with = try XCTUnwrap(progress(profile, series([96])).plannedGoalDate)

        XCTAssertEqual(calendar.dateComponents([.day], from: without, to: with).day, 14)
    }

    // MARK: Milestones

    func testMilestonesFollowTheTrend() throws {
        // 100 kg start; a week at 94 passes the 5% line (95 kg).
        let result = progress(makeProfile(), series(Array(repeating: 94, count: 7)))

        XCTAssertEqual(result.milestones.map(\.percent), [5])
        XCTAssertEqual(result.recentMilestone?.percent, 5)
        let next = try XCTUnwrap(result.nextMilestone)
        XCTAssertEqual(next.percent, 10)
        XCTAssertEqual(next.remainingKg, 4, accuracy: 0.001)
    }

    // MARK: Plateau

    private var flat: [WeightProgress.WeightDay] {
        series((0..<30).map { 95 + ($0 % 2 == 0 ? 0.1 : -0.1) })
    }

    func testFlatTrendIsAPlateau() throws {
        let result = progress(makeProfile(), flat)

        let plateau = try XCTUnwrap(result.plateau)
        XCTAssertGreaterThanOrEqual(plateau.days, ProgressCalculator.plateauMinimumDays)
    }

    func testNoPlateauInMaintenance() {
        let profile = makeProfile()
        profile.startMaintenance(atKg: 95)

        XCTAssertNil(progress(profile, flat).plateau)
    }

    func testPlateauComparesMeasuredMaintenanceWithThePlainDailyTarget() throws {
        let profile = makeProfile()
        // Four weeks eating 2,500 kcal with a flat weight: measured maintenance is about 2,500.
        let food = (1...28).map { WeightProgress.FoodDay(date: date(daysAgo: $0), calories: 2500) }
        let result = progress(profile, flat, food: food)

        XCTAssertEqual(result.dailyTarget, DayNutrition.dailyTarget(profile: profile, latestWeightKg: flat.last?.weightKg))
        let plateau = try XCTUnwrap(result.plateau)
        let first = try XCTUnwrap(plateau.suggestions.first)
        XCTAssertTrue(first.hasPrefix("Your measured maintenance"), first)
    }
}
