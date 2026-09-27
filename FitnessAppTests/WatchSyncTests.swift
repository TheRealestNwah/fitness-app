import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class WatchSyncTests: XCTestCase {
    private var container: ModelContainer!
    private var sync: WatchSync!

    override func setUp() async throws {
        let schema = Schema([UserProfile.self, WeightEntry.self, FoodItem.self, FoodLogEntry.self, VitalsEntry.self,
                             WaterEntry.self, Recipe.self, MealPlanEntry.self, SavedMeal.self, FastingSession.self,
                             ExerciseEntry.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        sync = WatchSync()
        sync.start(container: container)
    }

    private func water() throws -> [WaterEntry] {
        try container.mainContext.fetch(FetchDescriptor<WaterEntry>())
    }

    func testRecordsLogAsWaterEntry() throws {
        let log = WatchWaterLog(date: Date(timeIntervalSince1970: 1_800_000_000), amountMl: 250)
        sync.record(log)
        let entries = try water()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.uuid, log.id)
        XCTAssertEqual(entries.first?.date, log.date)
        XCTAssertEqual(entries.first?.amountMl, 250)
    }

    func testDuplicateDeliveryIsRecordedOnce() throws {
        let log = WatchWaterLog(date: .now, amountMl: 500)
        sync.record(log)
        sync.record(log)
        XCTAssertEqual(try water().count, 1)
    }

    func testDistinctLogsAreAllRecorded() throws {
        sync.record(WatchWaterLog(date: .now, amountMl: 250))
        sync.record(WatchWaterLog(date: .now, amountMl: 250))
        XCTAssertEqual(try water().map(\.amountMl).reduce(0, +), 500)
    }

    func testRecordingWithProfileRefreshesSnapshot() throws {
        let profile = UserProfile(name: "Sam", sex: .female, birthDate: Date(timeIntervalSince1970: 0), heightCm: 168,
                                  startWeightKg: 80, goalWeightKg: 70, activityLevel: .light, weeklyLossKg: 0.5,
                                  unitSystem: .metric)
        container.mainContext.insert(profile)
        sync.record(WatchWaterLog(date: .now, amountMl: 300))
        XCTAssertEqual(try water().count, 1)
        guard let data = UserDefaults(suiteName: WidgetSnapshot.appGroup)?.data(forKey: WidgetSnapshot.key) else {
            throw XCTSkip("App Group defaults unavailable here")
        }
        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        XCTAssertEqual(snapshot.waterMl, 300)
    }

    func testWithoutContainerDoesNothing() {
        WatchSync().record(WatchWaterLog(date: .now, amountMl: 250))
    }
}
