import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class QuickLogTests: XCTestCase {
    // Held so the context stays valid: a ModelContext doesn't keep its container alive.
    private var container: ModelContainer!
    private var context: ModelContext!
    private let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: .now)!

    override func setUp() async throws {
        container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        context = container.mainContext
    }

    @discardableResult
    private func addProfile(_ system: UnitSystem = .metric) -> UserProfile {
        let profile = UserProfile(name: "Sam", sex: .female, birthDate: Date(timeIntervalSince1970: 0), heightCm: 168,
                                  startWeightKg: 80, goalWeightKg: 70, activityLevel: .light, weeklyLossKg: 0.5,
                                  unitSystem: system)
        context.insert(profile)
        return profile
    }

    func testWaterDefaultsToOneGlassInTheUserUnits() throws {
        addProfile(.imperial)
        let total = try QuickLog.water(ml: nil, context: context, now: noon)
        XCTAssertEqual(total, 236.6, accuracy: 0.01)
    }

    func testWaterReturnsTodaysRunningTotal() throws {
        addProfile()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: noon)!
        try QuickLog.water(ml: 1000, context: context, now: yesterday)
        try QuickLog.water(ml: 250, context: context, now: noon)
        XCTAssertEqual(try QuickLog.water(ml: 500, context: context, now: noon), 750)
    }

    func testWaterWorksWithoutAProfile() throws {
        XCTAssertEqual(try QuickLog.water(ml: nil, context: context, now: noon), 250)
    }

    func testWaterRejectsImplausibleAmounts() {
        for amount in [0.0, -100, 5001] {
            XCTAssertThrowsError(try QuickLog.water(ml: amount, context: context, now: noon)) {
                XCTAssertEqual($0 as? QuickLogError, .waterOutOfRange)
            }
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WaterEntry>()), 0)
    }

    func testWeightAddsEntry() throws {
        addProfile()
        let entry = try QuickLog.weight(kg: 78.4, context: context, now: noon)
        XCTAssertEqual(entry.weightKg, 78.4)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WeightEntry>()), 1)
    }

    func testWeightRejectsOutOfRange() {
        XCTAssertThrowsError(try QuickLog.weight(kg: 5, context: context)) {
            XCTAssertEqual($0 as? QuickLogError, .weightOutOfRange)
        }
        XCTAssertThrowsError(try QuickLog.weight(kg: 500, context: context))
    }

    func testCaloriesLeftSubtractsTodaysFood() throws {
        let profile = addProfile()
        let target = Double(profile.calorieTarget(currentWeightKg: profile.startWeightKg))
        context.insert(FoodLogEntry(date: noon, mealType: .lunch, foodName: "Soup", servings: 1, servingDescription: "1 bowl",
                                    calories: 400, protein: 10, carbs: 40, fat: 15))
        XCTAssertEqual(try QuickLog.caloriesLeft(context: context, now: noon), target - 400, accuracy: 0.5)
    }

    func testCaloriesLeftNeedsAProfile() {
        XCTAssertThrowsError(try QuickLog.caloriesLeft(context: context)) {
            XCTAssertEqual($0 as? QuickLogError, .noProfile)
        }
    }

    func testToggleFastStartsWithTheLastTargetThenEnds() throws {
        let earlier = FastingSession(start: noon.addingTimeInterval(-86_400 * 2), targetHours: 18)
        earlier.end = noon.addingTimeInterval(-86_400)
        context.insert(earlier)

        let started = try QuickLog.toggleFast(context: context, now: noon)
        XCTAssertEqual(started.targetHours, 18)
        XCTAssertNil(started.end)
        XCTAssertEqual(QuickLog.activeFast(context: context)?.uuid, started.uuid)

        let later = noon.addingTimeInterval(3600)
        let ended = try QuickLog.toggleFast(context: context, now: later)
        XCTAssertEqual(ended.uuid, started.uuid)
        XCTAssertEqual(ended.end, later)
        XCTAssertNil(QuickLog.activeFast(context: context))
    }

    func testToggleFastDefaultsToSixteenHours() throws {
        XCTAssertEqual(try QuickLog.toggleFast(context: context, now: noon).targetHours, 16)
    }

    #if os(iOS)
    func testHomeQuickActionsRoundTripAndFollowTheFast() {
        let idle = HomeQuickAction.items(fastRunning: false)
        XCTAssertEqual(idle.compactMap { HomeQuickAction($0) }, HomeQuickAction.allCases)
        XCTAssertNotEqual(idle.last?.localizedTitle, HomeQuickAction.items(fastRunning: true).last?.localizedTitle)
    }
    #endif
}
