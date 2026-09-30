import SwiftData
import XCTest
@testable import FitnessApp

final class HungerCorrelationTests: XCTestCase {
    private let today = Calendar.current.startOfDay(for: .now)

    private func day(_ offset: Int, hour: Double = 12) -> Date {
        today.adding(days: -offset).addingTimeInterval(hour * 3600)
    }

    func testAveragesHungerPerDayAgainstTheDaysTotal() {
        let food = [(date: day(1, hour: 8), value: 30.0), (date: day(1, hour: 19), value: 50.0), (date: day(2), value: 40.0)]
        let hunger = [(date: day(1, hour: 0), rating: 2), (date: day(1, hour: 0), rating: 4), (date: day(2, hour: 0), rating: 5)]
        let pairs = CorrelationCalculator.hungerVersus(food, hunger: hunger)
        XCTAssertEqual(pairs.map(\.x), [40, 80])
        XCTAssertEqual(pairs.map(\.y), [5, 3])
    }

    func testDaysMissingEitherSideAreLeftOut() {
        let food = [(date: day(1), value: 30.0), (date: day(3), value: 0.0)]
        let hunger = [(date: day(1), rating: 3), (date: day(2), rating: 4), (date: day(3), rating: 1)]
        XCTAssertEqual(CorrelationCalculator.hungerVersus(food, hunger: hunger).count, 1)
    }

    func testHigherProteinDaysShowLowerHunger() throws {
        let pairs = (1...8).map { i in
            CorrelationCalculator.Pair(date: day(i), x: i <= 4 ? 60 : 130, y: i <= 4 ? 4 : 2)
        }
        let split = try XCTUnwrap(CorrelationCalculator.split(pairs))
        XCTAssertEqual(split.difference, -2)
    }

    func testRatingLabelsCoverTheRange() {
        for value in MealRating.range {
            XCTAssertFalse(MealRating.hungerLabel(value).isEmpty)
            XCTAssertFalse(MealRating.moodLabel(value).isEmpty)
        }
    }

    @MainActor
    func testCheckInStoresTheStartOfDay() throws {
        let container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let checkIn = MealCheckIn(day: day(0, hour: 13), mealType: .lunch, hunger: 4)
        container.mainContext.insert(checkIn)
        try container.mainContext.save()
        XCTAssertEqual(checkIn.day, today)
        XCTAssertEqual(checkIn.mealType, .lunch)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<MealCheckIn>()), 1)
    }
}
