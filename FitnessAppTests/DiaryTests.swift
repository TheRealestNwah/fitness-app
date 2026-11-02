import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class DiaryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let today = Calendar.current.startOfDay(for: .now)

    override func setUp() async throws {
        container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        context = container.mainContext
    }

    private func spinach() -> FoodItem {
        let food = FoodItem(name: "Spinach", servingDescription: "100 g", calories: 23, protein: 3, carbs: 4, fat: 0.4,
                            fiber: 2, sodium: 80)
        food.potassium = 560
        var micros = Micronutrients()
        micros.iron = 3
        micros.vitaminC = 28
        food.micros = micros
        context.insert(food)
        return food
    }

    private func entryCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<FoodLogEntry>())
    }

    // MARK: Snapshots carry every nutrient

    func testRecipeFromASavedFoodCarriesItsOtherNutrients() {
        let food = spinach()
        // 200 g of spinach in a recipe that makes 2 servings: 100 g per serving.
        let recipe = Recipe(name: "Saag", mealType: .dinner, servings: 2, prepMinutes: 20,
                            ingredients: [Ingredient(name: "Spinach", amount: "200 g", calories: 46, protein: 6, carbs: 8,
                                                     fat: 0.8, otherNutrients: food.otherNutrients.scaled(by: 2))],
                            instructions: "")
        context.insert(recipe)
        let entry = Diary(context).log(recipe, servings: 1.5, as: .dinner, on: today)
        XCTAssertEqual(entry.calories, 34.5, accuracy: 0.001)
        XCTAssertEqual(entry.fiber, 3, accuracy: 0.001)
        XCTAssertEqual(entry.sodium, 120, accuracy: 0.001)
        XCTAssertEqual(entry.potassium, 840, accuracy: 0.001)
        XCTAssertEqual(entry.micros.iron, 4.5, accuracy: 0.001)
        XCTAssertEqual(entry.micros.vitaminC, 42, accuracy: 0.001)
    }

    func testTypedInIngredientsLeaveOtherNutrientsAtZero() {
        let recipe = Recipe(name: "Toast", mealType: .breakfast, servings: 1, prepMinutes: 5,
                            ingredients: [Ingredient(name: "Bread", amount: "1 slice", calories: 80, protein: 3, carbs: 15, fat: 1)],
                            instructions: "")
        XCTAssertEqual(recipe.otherNutrientsPerServing, OtherNutrients())
    }

    func testIngredientsSavedBeforeOtherNutrientsStillDecode() throws {
        let old = #"{"id":"7C9E6679-7425-40DE-944B-E07FC1F90AE7","name":"Rice","amount":"1 cup","calories":200,"protein":4,"carbs":45,"fat":0.4}"#
        let ingredient = try JSONDecoder().decode(Ingredient.self, from: Data(old.utf8))
        XCTAssertNil(ingredient.otherNutrients)
        let partial = try JSONDecoder().decode(OtherNutrients.self, from: Data(#"{"fiber":2}"#.utf8))
        XCTAssertEqual(partial.fiber, 2)
        XCTAssertEqual(partial.micros, Micronutrients())
    }

    func testPlannedRecipeAndBatchPortionCarryOtherNutrients() throws {
        let food = spinach()
        let recipe = Recipe(name: "Saag", mealType: .dinner, servings: 2, prepMinutes: 20,
                            ingredients: [Ingredient(name: "Spinach", amount: "200 g", calories: 46, protein: 6, carbs: 8,
                                                     fat: 0.8, otherNutrients: food.otherNutrients.scaled(by: 2))],
                            instructions: "")
        context.insert(recipe)
        let planned = MealPlanEntry(recipe: recipe, day: today, mealType: .dinner)
        context.insert(planned)
        XCTAssertEqual(Diary(context).log(planned).micros.iron, 3, accuracy: 0.001)

        // The whole recipe (6 mg iron) split into 4 portions.
        let batch = MealPrepBatch(recipe: recipe, portions: 4)
        context.insert(batch)
        let portion = try XCTUnwrap(Diary(context).logPortion(of: batch, as: .lunch, on: today))
        XCTAssertEqual(portion.micros.iron, 1.5, accuracy: 0.001)
        XCTAssertEqual(portion.fiber, 1, accuracy: 0.001)
    }

    // MARK: Remembered amounts

    func testEveryWayOfLoggingAFoodRemembersTheAmount() {
        let food = spinach()
        let diary = Diary(context)
        diary.log(food, servings: 2.5, as: .lunch, on: today)
        XCTAssertEqual(food.lastServings, 2.5)
        XCTAssertEqual(food.useCount, 1)

        // Suggestions, the menu bar and drag and drop log without an amount: they use the last one.
        XCTAssertEqual(diary.log(food, as: .dinner, on: today).servings, 2.5)
        XCTAssertTrue(FoodReference(food: food).log(on: today, as: .snack, context: context))
        let dropped = try? context.fetch(FetchDescriptor<FoodLogEntry>()).filter { $0.mealType == .snack }
        XCTAssertEqual(dropped?.first?.servings, 2.5)
        XCTAssertEqual(food.useCount, 3)
    }

    func testAFoodNeverLoggedStartsAtOneServing() {
        XCTAssertEqual(Diary(context).log(spinach(), as: .lunch, on: today).servings, 1)
    }

    // MARK: Undo

    func testLoggingCanBeUndone() throws {
        let undo = UndoCenter()
        Diary(context, undo: undo).log(spinach(), as: .lunch, on: today)
        XCTAssertEqual(try entryCount(), 1)
        XCTAssertNotNil(undo.toast)
        undo.undo()
        XCTAssertEqual(try entryCount(), 0)
    }

    func testCopyingYesterdaysMealIsOneUndo() throws {
        let yesterday = today.adding(days: -1)
        let diary = Diary(context)
        let logged = diary.log([(food: spinach(), servings: 1), (food: spinach(), servings: 2)], as: .lunch, on: yesterday)
        let undo = UndoCenter()
        Diary(context, undo: undo).copy(logged, to: .lunch, on: today)
        XCTAssertEqual(try entryCount(), 4)
        undo.undo()
        XCTAssertEqual(try entryCount(), 2)
    }

    func testLoggingAPlanItemCanBeUndone() throws {
        let recipe = Recipe(name: "Chili", mealType: .dinner, servings: 4, prepMinutes: 40,
                            ingredients: [Ingredient(name: "Beans", amount: "2 cans", calories: 1600, protein: 100, carbs: 240, fat: 20)],
                            instructions: "")
        let batch = MealPrepBatch(recipe: recipe, portions: 4)
        context.insert(batch)
        let planned = MealPlanEntry(batch: batch, day: today, mealType: .dinner)
        context.insert(planned)
        let undo = UndoCenter()
        Diary(context, undo: undo).log(planned)
        XCTAssertTrue(planned.isLogged)
        XCTAssertEqual(batch.portionsLeft, 3)
        XCTAssertEqual(try entryCount(), 1)
        undo.undo()
        XCTAssertFalse(planned.isLogged)
        XCTAssertEqual(batch.portionsLeft, 4)
        XCTAssertEqual(try entryCount(), 0)
    }

    func testLoggingABatchPortionCanBeUndone() throws {
        let recipe = Recipe(name: "Chili", mealType: .dinner, servings: 4, prepMinutes: 40, ingredients: [], instructions: "")
        let batch = MealPrepBatch(recipe: recipe, portions: 2)
        context.insert(batch)
        let undo = UndoCenter()
        Diary(context, undo: undo).logPortion(of: batch, as: .lunch, on: today)
        XCTAssertEqual(batch.portionsLeft, 1)
        undo.undo()
        XCTAssertEqual(batch.portionsLeft, 2)
        XCTAssertEqual(try entryCount(), 0)
    }

    func testChangingAmountAndMealCanBeUndone() {
        let entry = Diary(context).log(spinach(), servings: 1, as: .lunch, on: today)
        let undo = UndoCenter()
        Diary(context, undo: undo).change(entry, servings: 2, meal: .dinner)
        XCTAssertEqual(entry.servings, 2)
        XCTAssertEqual(entry.mealType, .dinner)
        XCTAssertEqual(entry.micros.iron, 6, accuracy: 0.001)
        undo.undo()
        XCTAssertEqual(entry.servings, 1)
        XCTAssertEqual(entry.mealType, .lunch)
        XCTAssertEqual(entry.micros.iron, 3, accuracy: 0.001)
    }

    func testDeletingCanBeUndoneWithEveryNutrient() throws {
        let entry = Diary(context).log(spinach(), as: .lunch, on: today)
        let undo = UndoCenter()
        Diary(context, undo: undo).delete([entry])
        XCTAssertEqual(try entryCount(), 0)
        undo.undo()
        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<FoodLogEntry>()).first)
        XCTAssertEqual(restored.fiber, 2)
        XCTAssertEqual(restored.micros.vitaminC, 28)
    }

    func testWithoutAnUndoCenterNothingIsOffered() throws {
        let entry = Diary(context).log(spinach(), as: .lunch, on: today)
        Diary(context).delete([entry])
        XCTAssertEqual(try entryCount(), 0)
    }
}
