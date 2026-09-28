import XCTest
@testable import FitnessApp

final class GroceryRemindersTests: XCTestCase {
    private typealias Line = GroceryReminders.Line
    private typealias Existing = GroceryReminders.Existing

    func testFirstSendAddsEverything() {
        let lines = [Line(title: "Oats", notes: "80 g"), Line(title: "Milk", notes: "500 ml")]
        let changes = GroceryReminders.changes(existing: [], lines: lines)
        XCTAssertEqual(changes.add, lines)
        XCTAssertTrue(changes.update.isEmpty)
        XCTAssertTrue(changes.remove.isEmpty)
    }

    func testSendingAgainUpdatesInsteadOfDuplicating() {
        let existing = [Existing(id: "1", title: "Oats", notes: "80 g", isOurs: true),
                        Existing(id: "2", title: "milk", notes: "250 ml", isOurs: true),
                        Existing(id: "3", title: "Spinach", notes: "1 bag", isOurs: true),
                        Existing(id: "4", title: "Birthday candles", notes: "", isOurs: false)]
        let lines = [Line(title: "Oats", notes: "80 g"), Line(title: "Milk", notes: "500 ml"), Line(title: "Eggs", notes: "6")]
        let changes = GroceryReminders.changes(existing: existing, lines: lines)
        XCTAssertEqual(changes.add, [Line(title: "Eggs", notes: "6")])
        XCTAssertEqual(changes.update.map(\.id), ["2"])
        XCTAssertEqual(changes.update.map(\.notes), ["500 ml"])
        // Stride's spinach is no longer needed; the user's own reminder stays.
        XCTAssertEqual(changes.remove, ["3"])
    }
}
