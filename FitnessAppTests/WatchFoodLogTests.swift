import SwiftData
import XCTest
@testable import FitnessApp

final class WatchFoodLogTests: XCTestCase {
    func testRoundTripsThroughUserInfo() {
        let food = WatchFoodLog(date: Date(timeIntervalSince1970: 1_800_000_000), foodID: UUID(), servings: 1.5)
        XCTAssertEqual(WatchFoodLog(userInfo: food.userInfo), food)
        let quick = WatchFoodLog(date: Date(timeIntervalSince1970: 1_800_000_000), foodID: nil, kcal: 250)
        XCTAssertEqual(WatchFoodLog(userInfo: quick.userInfo), quick)
    }

    func testRejectsWaterAndJunk() {
        XCTAssertNil(WatchFoodLog(userInfo: WatchWaterLog(date: .now, amountMl: 250).userInfo))
        XCTAssertNil(WatchFoodLog(userInfo: [:]))
        XCTAssertNil(WatchFoodLog(userInfo: WatchFoodLog(date: .now, foodID: nil, kcal: 0).userInfo))
        XCTAssertNil(WatchFoodLog(userInfo: WatchFoodLog(date: .now, foodID: nil, kcal: 6000).userInfo))
        XCTAssertNil(WatchFoodLog(userInfo: WatchFoodLog(date: .now, foodID: UUID(), servings: 0).userInfo))
    }

    func testQuickFoodsPutFavouritesFirstThenRecent() {
        let now = Date.now
        func candidate(_ name: String, favourite: Bool = false, used: TimeInterval? = nil, last: Double? = nil)
            -> WatchQuickFood.Candidate {
            .init(id: UUID(), name: name, kcalPerServing: 100, lastServings: last, isFavorite: favourite,
                  lastUsed: used.map { now.addingTimeInterval(-$0) })
        }
        let picked = WatchQuickFood.pick([candidate("Never used"), candidate("Old", used: 3_600),
                                          candidate("Fave", favourite: true), candidate("New", used: 60, last: 2)])
        XCTAssertEqual(picked.map(\.name), ["Fave", "New", "Old"])
        XCTAssertEqual(picked[1].servings, 2)
        XCTAssertEqual(picked[1].kcal, 200)
        XCTAssertEqual(WatchQuickFood.pick((0..<20).map { candidate("\($0)", used: Double($0)) }).count, WatchQuickFood.limit)
    }
}

@MainActor
final class WatchFoodSyncTests: XCTestCase {
    private var container: ModelContainer!
    private var sync: WatchSync!

    override func setUp() async throws {
        container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        sync = WatchSync()
        sync.start(container: container)
    }

    private func diary() throws -> [FoodLogEntry] {
        try container.mainContext.fetch(FetchDescriptor<FoodLogEntry>())
    }

    func testLogsAQuickFoodOnceAtTheWatchTime() throws {
        let oats = FoodItem(name: "Oats", servingDescription: "40 g", calories: 150, protein: 5, carbs: 27, fat: 3)
        container.mainContext.insert(oats)
        let breakfastTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!
        let log = WatchFoodLog(date: breakfastTime, foodID: oats.uuid, servings: 2)
        sync.record(log)
        sync.record(log)
        let entries = try diary()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.uuid, log.id)
        XCTAssertEqual(entries.first?.date, breakfastTime)
        XCTAssertEqual(entries.first?.mealType, .breakfast)
        XCTAssertEqual(entries.first?.calories, 300)
        XCTAssertEqual(oats.lastServings, 2)
    }

    func testQuickAddCalories() throws {
        sync.record(WatchFoodLog(date: .now, foodID: nil, kcal: 180))
        XCTAssertEqual(try diary().first?.calories, 180)
    }

    func testUnknownFoodIsIgnored() throws {
        sync.record(WatchFoodLog(date: .now, foodID: UUID(), servings: 1))
        XCTAssertTrue(try diary().isEmpty)
    }
}
