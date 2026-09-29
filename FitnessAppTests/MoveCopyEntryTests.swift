import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class MoveCopyEntryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let today = Calendar.current.startOfDay(for: .now)

    override func setUp() async throws {
        container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        context = container.mainContext
    }

    private func oats() -> FoodLogEntry {
        let entry = FoodLogEntry(date: MealType.breakfast.logDate(on: today), mealType: .breakfast, foodName: "Oats",
                                 servings: 1, servingDescription: "40 g", calories: 150, protein: 5, carbs: 27, fat: 3)
        context.insert(entry)
        return entry
    }

    func testMoveChangesMealAndDayAndCanBeUndone() {
        let entry = oats()
        let undo = UndoCenter()
        let tomorrow = today.adding(days: 1)
        context.moveDiaryEntry(entry, to: .lunch, on: tomorrow, undo: undo)
        XCTAssertEqual(entry.mealType, .lunch)
        XCTAssertTrue(Calendar.current.isDate(entry.date, inSameDayAs: tomorrow))
        undo.undo()
        XCTAssertEqual(entry.mealType, .breakfast)
        XCTAssertTrue(Calendar.current.isDate(entry.date, inSameDayAs: today))
    }

    func testCopyAddsAnIndependentEntry() throws {
        let entry = oats()
        let undo = UndoCenter()
        context.copyDiaryEntry(entry, to: .snack, on: today, undo: undo)
        let all = try context.fetch(FetchDescriptor<FoodLogEntry>())
        XCTAssertEqual(all.count, 2)
        let copy = try XCTUnwrap(all.first { $0.uuid != entry.uuid })
        XCTAssertEqual(copy.mealType, .snack)
        XCTAssertEqual(copy.calories, 150)
        undo.undo()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodLogEntry>()), 1)
    }

    func testDroppingAnEntryOnAMealMovesIt() {
        let entry = oats()
        XCTAssertTrue(FoodReference(entry: entry).log(on: today, as: .dinner, context: context))
        XCTAssertEqual(entry.mealType, .dinner)
    }
}
