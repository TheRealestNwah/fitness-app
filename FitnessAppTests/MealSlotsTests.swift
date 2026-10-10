import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class MealSlotsTests: XCTestCase {
    override func tearDown() async throws {
        MealSlots.shared.slots = MealSlots.defaults
    }

    private let brunch = MealSlot(id: "meal-1", name: "Brunch", icon: "fork.knife", hour: 10, reminds: true, share: 0.2)

    func testDefaultsKeepTheFourOriginalMeals() {
        XCTAssertEqual(MealType.allCases, [.breakfast, .lunch, .dinner, .snack])
        XCTAssertEqual(MealType.snack.label, "Snacks")
        XCTAssertEqual(MealType.dinner.typicalHour, 19)
        XCTAssertEqual(MealType.current(at: date(hour: 9)), .breakfast)
        XCTAssertEqual(MealType.current(at: date(hour: 23)), .snack)
        XCTAssertEqual(MealType.allCases.reduce(0) { $0 + $1.budgetShare }, 1, accuracy: 0.0001)
    }

    func testEmptyOrBrokenJSONMeansDefaults() {
        XCTAssertEqual(MealSlots.decode(""), MealSlots.defaults)
        XCTAssertEqual(MealSlots.decode("not json"), MealSlots.defaults)
        XCTAssertEqual(MealSlots.decode("[]"), MealSlots.defaults)
    }

    func testEncodeDecodeRoundTrip() {
        let list = MealSlots.defaults + [brunch]
        XCTAssertEqual(MealSlots.decode(MealSlots.encode(list)), list)
    }

    func testSanitisedDropsDuplicatesAndFixesNamesAndHours() {
        var odd = brunch
        odd.name = "  "
        odd.hour = 40
        let clean = MealSlots.sanitised([brunch, brunch, odd.with(id: "meal-2")])
        XCTAssertEqual(clean.count, 2)
        XCTAssertEqual(clean[1].name, "Meal")
        XCTAssertEqual(clean[1].hour, 23)
    }

    func testCustomMealsAppearInOrderWithTheirOwnSettings() {
        MealSlots.shared.slots = [brunch] + MealSlots.defaults
        XCTAssertEqual(MealType.allCases.first?.label, "Brunch")
        let meal = MealType(id: "meal-1")
        XCTAssertEqual(meal.inSentence, "brunch")
        XCTAssertEqual(meal.typicalHour, 10)
        XCTAssertEqual(meal.order, 0)
        XCTAssertEqual(MealType.dinner.order, 3)
        XCTAssertEqual(MealType.allCases.reduce(0) { $0 + $1.budgetShare }, 1, accuracy: 0.0001)
        XCTAssertNotNil(MealType(rawValue: "meal-1"))
        XCTAssertNil(MealType(rawValue: "gone"))
    }

    func testCurrentMealWithCustomSlotsIsTheLatestStarted() {
        MealSlots.shared.slots = [brunch, MealSlot(id: "late", name: "Late", icon: "moon.stars.fill", hour: 21,
                                                   reminds: false, share: 0.1)]
        XCTAssertEqual(MealType.current(at: date(hour: 11)).rawValue, "meal-1")
        XCTAssertEqual(MealType.current(at: date(hour: 22)).rawValue, "late")
        XCTAssertEqual(MealType.current(at: date(hour: 3)).rawValue, "late")
    }

    func testRemindersFollowTheMealsThatAskForThem() {
        MealSlots.shared.slots = [brunch] + MealSlots.defaults.filter { $0.id == "snack" }
        let times = ReminderPlanner.mealTimes
        XCTAssertEqual(times.map(\.meal.rawValue), ["meal-1"])
        XCTAssertEqual(times.first?.hour, 10)
    }

    // MARK: CSV mapping

    func testImportMapsNamesToTheClosestSlot() {
        MealSlots.shared.slots = MealSlots.defaults + [brunch]
        XCTAssertEqual(DataImporter.meal("Brunch"), MealType(id: "meal-1"))
        XCTAssertEqual(DataImporter.meal("Breakfast (late)"), .breakfast)
        XCTAssertEqual(DataImporter.meal("Supper"), .dinner)
        XCTAssertEqual(DataImporter.meal("Midnight feast"), .snack)
        XCTAssertEqual(DataImporter.meal(""), .snack)
    }

    func testImportFallsBackToTheLastMealWhenSnacksIsGone() {
        MealSlots.shared.slots = [brunch, MealSlots.defaults[2]]
        XCTAssertEqual(DataImporter.meal("elevenses"), .dinner)
        XCTAssertEqual(DataImporter.meal("Dinner"), .dinner)
    }

    func testExportWritesCustomNamesAndPlainIdsForUnrenamedDefaults() {
        var renamed = MealSlots.defaults
        renamed[0].name = "Morning meal"
        MealSlots.shared.slots = renamed + [brunch]
        XCTAssertEqual(MealSlots.shared.exportName(for: .lunch), "lunch")
        XCTAssertEqual(MealSlots.shared.exportName(for: .breakfast), "Morning meal")
        XCTAssertEqual(MealSlots.shared.exportName(for: MealType(id: "meal-1")), "Brunch")
    }

    // MARK: Migration

    func testExistingEntriesKeepTheirMealUnderTheDefaultSlots() throws {
        let container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let entry = FoodLogEntry(date: .now, mealType: .dinner, foodName: "Pasta", servings: 1, servingDescription: "bowl",
                                 calories: 500, protein: 15, carbs: 80, fat: 10)
        context.insert(entry)
        XCTAssertEqual(entry.mealTypeRaw, "dinner")
        XCTAssertEqual(entry.mealType, .dinner)
        XCTAssertEqual(entry.mealType.label, "Dinner")
    }

    func testRemovingAMealMovesItsEntriesToTheHeir() throws {
        let container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        MealSlots.shared.slots = MealSlots.defaults + [brunch]
        let food = FoodLogEntry(date: .now, mealType: MealType(id: "meal-1"), foodName: "Eggs", servings: 1,
                                servingDescription: "2", calories: 150, protein: 12, carbs: 1, fat: 10)
        let plan = MealPlanEntry(day: .now, mealType: MealType(id: "meal-1"), title: "Pancakes",
                                 caloriesPerServing: 300, proteinPerServing: 8, carbsPerServing: 50, fatPerServing: 6)
        context.insert(food)
        context.insert(plan)
        MealsEditor.reassign(from: "meal-1", to: "snack", context: context)
        XCTAssertEqual(food.mealTypeRaw, "snack")
        XCTAssertEqual(plan.mealTypeRaw, "snack")
    }

    func testProfileSlotsLoadThroughApply() {
        MealSlots.shared.apply(json: MealSlots.encode([brunch]))
        XCTAssertEqual(MealSlots.shared.slots, [brunch])
        MealSlots.shared.apply(json: "")
        XCTAssertEqual(MealSlots.shared.slots, MealSlots.defaults)
    }

    private func date(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
    }
}

private extension MealSlot {
    func with(id: String) -> MealSlot {
        var copy = self
        copy.id = id
        return copy
    }
}
