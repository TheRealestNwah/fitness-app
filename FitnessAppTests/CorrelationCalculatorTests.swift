import XCTest
@testable import FitnessApp

final class CorrelationCalculatorTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func day(_ n: Int, hour: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: n, hour: hour))!
    }

    func testSleepPairsWithThatDaysIntake() {
        let pairs = CorrelationCalculator.sleepVersusIntake(
            sleep: [(day(1, hour: 7), 6), (day(2, hour: 7), 8), (day(3, hour: 7), 7)],
            food: [(day(1, hour: 9), 800), (day(1, hour: 19), 1200), (day(2, hour: 12), 1700)],
            calendar: calendar)
        XCTAssertEqual(pairs.map(\.x), [6, 8])            // day 3 has no food logged
        XCTAssertEqual(pairs.map(\.y), [2000, 1700])
    }

    func testSodiumPairsWithTheDayBeforeTheReading() {
        let pairs = CorrelationCalculator.sodiumVersusSystolic(
            readings: [(day(2), 130), (day(3), 120), (day(5), 125)],
            food: [(day(1, hour: 12), 2500), (day(2, hour: 12), 0), (day(4, hour: 12), 1500)],
            calendar: calendar)
        // Day 3's reading follows a day with no sodium recorded, so it's left out.
        XCTAssertEqual(pairs.map(\.x), [2500, 1500])
        XCTAssertEqual(pairs.map(\.y), [130, 125])
    }

    func testSplitComparesHalves() {
        let pairs = zip([5.0, 6, 6.5, 7.5, 8, 9], [2400.0, 2300, 2200, 1900, 1800, 1700]).enumerated().map {
            CorrelationCalculator.Pair(date: day($0.offset + 1), x: $0.element.0, y: $0.element.1)
        }
        let split = CorrelationCalculator.split(pairs)
        XCTAssertEqual(split?.medianX ?? 0, 7, accuracy: 0.001)
        XCTAssertEqual(split?.lowMeanY ?? 0, 2300, accuracy: 0.001)
        XCTAssertEqual(split?.highMeanY ?? 0, 1800, accuracy: 0.001)
        XCTAssertEqual(split?.difference ?? 0, -500, accuracy: 0.001)
    }

    func testSplitNeedsEnoughPairs() {
        let pairs = (1...5).map { CorrelationCalculator.Pair(date: day($0), x: Double($0), y: 1) }
        XCTAssertNil(CorrelationCalculator.split(pairs))
    }

    func testSplitNeedsVariationInX() {
        let pairs = (1...6).map { CorrelationCalculator.Pair(date: day($0), x: 7, y: Double($0)) }
        XCTAssertNil(CorrelationCalculator.split(pairs))
    }
}
