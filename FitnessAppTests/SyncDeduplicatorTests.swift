import XCTest
import SwiftData
@testable import FitnessApp

@MainActor
final class SyncDeduplicatorTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }

    private func food(_ name: String, custom: Bool = false, uses: Int = 0) -> FoodItem {
        let item = FoodItem(name: name, servingDescription: "100 g", calories: 100, protein: 1, carbs: 1, fat: 1)
        item.isCustom = custom
        item.useCount = uses
        context.insert(item)
        return item
    }

    func testStableIDsMatchAcrossCallsAndDifferByKey() {
        XCTAssertEqual(SyncDeduplicator.stableID("food|egg"), SyncDeduplicator.stableID("food|egg"))
        XCTAssertNotEqual(SyncDeduplicator.stableID("food|egg"), SyncDeduplicator.stableID("food|egg white"))
    }

    func testBuiltInFoodCopiesMergeAndEntriesFollowTheKeeper() throws {
        let used = food("Oats", uses: 5)
        let spare = food("Oats", uses: 1)
        let entry = FoodLogEntry(date: .now, mealType: .breakfast, foodName: "Oats", servings: 1,
                                 servingDescription: "100 g", calories: 100, protein: 1, carbs: 1, fat: 1,
                                 foodItemID: spare.uuid)
        context.insert(entry)

        XCTAssertTrue(SyncDeduplicator.run(context: context))

        let left = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(left.map(\.uuid), [used.uuid])
        XCTAssertEqual(entry.foodItemID, used.uuid)
    }

    func testCustomFoodsWithTheSameNameAreLeftAlone() throws {
        _ = food("My shake", custom: true)
        _ = food("My shake", custom: true)
        XCTAssertFalse(SyncDeduplicator.run(context: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodItem>()), 2)
    }

    func testOnlyTheOldestProfileIsKept() throws {
        func profile(_ name: String, started: Date) -> UserProfile {
            let p = UserProfile(name: name, sex: .female, birthDate: Date(timeIntervalSince1970: 0), heightCm: 165,
                                startWeightKg: 80, goalWeightKg: 70, activityLevel: .light, weeklyLossKg: 0.5,
                                unitSystem: .metric)
            p.startDate = started
            context.insert(p)
            return p
        }
        _ = profile("Phone", started: Date(timeIntervalSince1970: 1_000))
        _ = profile("iPad", started: Date(timeIntervalSince1970: 2_000))

        SyncDeduplicator.run(context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<UserProfile>()).map(\.name), ["Phone"])
    }

    func testFavouriteWinsOverUseCount() {
        let favourite = FoodItem(name: "Rice", servingDescription: "100 g", calories: 130, protein: 3, carbs: 28, fat: 0)
        favourite.isFavorite = true
        let busy = FoodItem(name: "Rice", servingDescription: "100 g", calories: 130, protein: 3, carbs: 28, fat: 0)
        busy.useCount = 50
        XCTAssertTrue(SyncDeduplicator.keeps(favourite, over: busy))
        XCTAssertFalse(SyncDeduplicator.keeps(busy, over: favourite))
    }
}
