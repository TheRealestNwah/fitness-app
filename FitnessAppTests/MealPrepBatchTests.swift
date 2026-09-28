import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class MealPrepBatchTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        context = container.mainContext
    }

    private func chili(servings: Int = 4) -> Recipe {
        Recipe(name: "Chili", mealType: .dinner, servings: servings, prepMinutes: 40,
               ingredients: [Ingredient(name: "Beans", amount: "2 cans", calories: 1600, protein: 100, carbs: 240, fat: 20)],
               instructions: "")
    }

    func testPortionsSplitTheWholeRecipe() {
        // 1600 kcal over the recipe; split into 5 portions instead of its 4 servings.
        let batch = MealPrepBatch(recipe: chili(), portions: 5)
        XCTAssertEqual(batch.caloriesPerPortion, 320, accuracy: 0.001)
        XCTAssertEqual(batch.proteinPerPortion, 20, accuracy: 0.001)
        XCTAssertEqual(batch.portionsLeft, 5)
    }

    func testLoggingCountsDownUntilUsedUp() throws {
        let batch = MealPrepBatch(recipe: chili(), portions: 2)
        context.insert(batch)
        XCTAssertNotNil(batch.logPortion(on: .now, as: .lunch, context: context))
        XCTAssertNotNil(batch.logPortion(on: .now, as: .dinner, context: context))
        XCTAssertTrue(batch.isUsedUp)
        XCTAssertNil(batch.logPortion(on: .now, as: .dinner, context: context))
        let logged = try context.fetch(FetchDescriptor<FoodLogEntry>())
        XCTAssertEqual(logged.count, 2)
        XCTAssertEqual(logged.first?.calories ?? 0, 800, accuracy: 0.001)
    }

    func testPlanEntryLinksTheBatch() {
        let batch = MealPrepBatch(recipe: chili(), portions: 4)
        let entry = MealPlanEntry(batch: batch, day: .now, mealType: .lunch)
        XCTAssertEqual(entry.batchID, batch.uuid)
        XCTAssertEqual(entry.caloriesPerServing, 400, accuracy: 0.001)
    }
}
