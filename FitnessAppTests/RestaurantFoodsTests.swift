import SwiftData
import XCTest
@testable import FitnessApp

final class RestaurantFoodsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "RestaurantFoodsTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    @MainActor
    private func foods(_ context: ModelContext) throws -> [FoodItem] {
        try context.fetch(FetchDescriptor<FoodItem>())
    }

    func testEveryItemHasABrandAndPlausibleNumbers() {
        for food in SeedData.restaurantFoods {
            XCTAssertFalse(food.brand.isEmpty, food.name)
            // Energy from macros should be within reach of the listed calories.
            let fromMacros = food.protein * 4 + food.carbs * 4 + food.fat * 9
            XCTAssertEqual(fromMacros, food.calories, accuracy: max(30, food.calories * 0.15), food.displayName)
        }
        let names = SeedData.restaurantFoods.map(\.displayName)
        XCTAssertEqual(names.count, Set(names).count, "duplicate items")
    }

    @MainActor
    func testFreshInstallGetsEverything() throws {
        let context = try makeContext()
        SeedData.seedIfNeeded(context: context, defaults: defaults)
        XCTAssertEqual(try foods(context).count, SeedData.foods.count + SeedData.restaurantFoods.count)
    }

    @MainActor
    func testExistingInstallIsToppedUpOnce() throws {
        let context = try makeContext()
        for f in SeedData.foods { context.insert(f) }
        let bigMac = FoodItem(name: "Big Mac", brand: "McDonald's", servingDescription: "1 burger",
                              calories: 590, protein: 25, carbs: 46, fat: 34)
        context.insert(bigMac)
        try context.save()

        SeedData.seedIfNeeded(context: context, defaults: defaults)
        XCTAssertEqual(try foods(context).count, SeedData.foods.count + SeedData.restaurantFoods.count)
        XCTAssertEqual(try foods(context).filter { $0.name == "Big Mac" }.count, 1)

        // A deleted item stays deleted on the next launch.
        let taco = try XCTUnwrap(try foods(context).first { $0.name == "Crunchy Taco" })
        context.delete(taco)
        try context.save()
        SeedData.seedIfNeeded(context: context, defaults: defaults)
        XCTAssertNil(try foods(context).first { $0.name == "Crunchy Taco" })
    }
}
