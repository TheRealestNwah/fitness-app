import XCTest
@testable import FitnessApp

final class PartnerSummaryTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()
    private let today = Date(timeIntervalSince1970: 1_790_000_000)   // a fixed day, mid-afternoon UTC

    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(EnergyUnit.kcal.rawValue, forKey: EnergyUnit.storageKey)
        NumberPrivacy.shared.manual = false
        NumberPrivacy.shared.focus = false
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: today))!
    }

    private func review(daysLogged: Int = 6, average: Double? = 1850, change: Double? = -0.4) -> WeeklyReview {
        WeeklyReview(daysLogged: daysLogged, averageIntake: average, budget: 1900, weightChangeKg: change,
                     plannedWeeklyLossKg: 0.5, headline: "Steady week", suggestion: "Keep going")
    }

    private func input(weights: [(Int, Double)] = [(-42, 84), (-30, 82.6), (-1, 80.8)],
                       review: WeeklyReview? = nil,
                       calories: [Int: Double] = [-1: 1800, -3: 2100]) -> PartnerSummary.Input {
        PartnerSummary.Input(
            weights: weights.map { .init(date: day($0.0), weightKg: $0.1) },
            review: review ?? self.review(),
            loggingStreak: 12,
            proteinStreak: 3,
            caloriesByDay: Dictionary(uniqueKeysWithValues: calories.map { (day($0.key), $0.value) }),
            units: Units(system: .metric),
            today: today,
            calendar: calendar)
    }

    func testWeightTrendShowsChangeSinceStartAndOverFourWeeks() {
        let lines = PartnerSummary.weightTrendLines(input())
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("-3.2 kg since"), lines[0])
        XCTAssertTrue(lines[1].hasPrefix("-1.8 kg over the last 4 weeks"), lines[1])
    }

    func testWeightTrendSkipsFourWeeksWithoutAnOlderWeighIn() {
        let lines = PartnerSummary.weightTrendLines(input(weights: [(-10, 82), (-1, 81.5)]))
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].hasPrefix("-0.5 kg since"), lines[0])
    }

    func testWeightTrendNeedsTwoWeighIns() {
        XCTAssertEqual(PartnerSummary.weightTrendLines(input(weights: [(-1, 80)])), ["Not enough weigh-ins yet"])
        XCTAssertEqual(PartnerSummary.weightTrendLines(input(weights: [])), ["Not enough weigh-ins yet"])
    }

    func testWeekLinesLeaveOutMissingValues() {
        let full = PartnerSummary.weekLines(review(), units: Units(system: .metric))
        XCTAssertEqual(full, ["Logged food on 6 of 7 days", "Average 1850 kcal a day, target 1900 kcal",
                              "Weight -0.4 kg on the week before", "Steady week"])
        let empty = PartnerSummary.weekLines(review(daysLogged: 0, average: nil, change: nil), units: Units(system: .metric))
        XCTAssertEqual(empty, ["Logged food on 0 of 7 days"])
    }

    func testProteinStreakOnlyShowsFromTwoDays() {
        XCTAssertEqual(PartnerSummary.streakLines(logging: 5, protein: 1), ["Logged 5 days in a row"])
        XCTAssertEqual(PartnerSummary.streakLines(logging: 5, protein: 2).count, 2)
    }

    func testDailyCaloriesCoverTheSevenDaysBeforeToday() {
        let lines = PartnerSummary.dailyCalorieLines(input())
        XCTAssertEqual(lines.count, 7)
        XCTAssertTrue(lines[6].hasSuffix(": 1800 kcal"), lines[6])
        XCTAssertTrue(lines[4].hasSuffix(": 2100 kcal"), lines[4])
        XCTAssertTrue(lines[0].hasSuffix(": not logged"), lines[0])
    }

    func testDailyCaloriesAreOffByDefault() {
        let text = PartnerSummary.text(input(), options: .init())
        XCTAssertTrue(text.contains("Weight\n"))
        XCTAssertTrue(text.contains("Last 7 days\n"))
        XCTAssertTrue(text.contains("Streaks\n"))
        XCTAssertFalse(text.contains("Daily calories"))
        XCTAssertFalse(text.contains("1800 kcal"))
    }

    func testOnlyChosenSectionsAreIncluded() {
        let text = PartnerSummary.text(input(), options: .init(weightTrend: false, week: false, streaks: true, dailyCalories: true))
        XCTAssertFalse(text.contains("Weight\n"))
        XCTAssertFalse(text.contains("Last 7 days\n"))
        XCTAssertTrue(text.contains("Logged 12 days in a row"))
        XCTAssertTrue(text.contains("1800 kcal"))
    }

    func testNothingChosenGivesNoText() {
        let none = PartnerSummary.Options(weightTrend: false, week: false, streaks: false, dailyCalories: false)
        XCTAssertTrue(none.isEmpty)
        XCTAssertEqual(PartnerSummary.text(input(), options: none), "")
    }
}
