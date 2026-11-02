import XCTest
@testable import FitnessApp

final class TodayLayoutTests: XCTestCase {
    func testEmptyStorageIsTheDefault() {
        XCTAssertEqual(TodayLayout(storage: ""), .default)
        XCTAssertEqual(TodayLayout.default.visible, TodayCard.allCases)
    }

    func testStarterLayoutShowsOnlyTheEssentials() {
        XCTAssertEqual(TodayLayout.starter.visible, [.calories, .quickActions, .weight, .exercise, .water])
        XCTAssertTrue(TodayLayout.starter.hidden.contains(.fasting))
        XCTAssertEqual(TodayLayout(storage: TodayLayout.starter.storage), .starter)
    }

    func testStorageRoundTrips() {
        var layout = TodayLayout.default
        layout.move(fromOffsets: IndexSet(integer: layout.order.firstIndex(of: .tip)!), toOffset: 0)
        layout.setVisible(.vitals, false)
        layout.setVisible(.water, false)
        let restored = TodayLayout(storage: layout.storage)
        XCTAssertEqual(restored, layout)
        XCTAssertEqual(restored.visible.first, .tip)
        XCTAssertFalse(restored.visible.contains(.vitals))
    }

    func testMoveMatchesListSemantics() {
        var layout = TodayLayout(order: [.calories, .weight, .water, .tip], hidden: [])
        layout.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)      // calories after water
        XCTAssertEqual(layout.order, [.weight, .water, .calories, .tip])
        layout.move(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        XCTAssertEqual(layout.order, [.tip, .weight, .water, .calories])
    }

    func testUnknownCardsAreIgnored() {
        let layout = TodayLayout(storage: "tip,retired,calories|retired,water")
        XCTAssertFalse(layout.order.contains { $0.rawValue == "retired" })
        XCTAssertEqual(layout.hidden, [.water])
        XCTAssertEqual(Set(layout.order), Set(TodayCard.allCases))
    }

    func testNewCardsAppearAtTheirDefaultPosition() {
        // Saved before "progress" existed, with calories moved to the end.
        let layout = TodayLayout(storage: "quickActions,weight,activity,weeklyReview,water,plan,vitals,tip,calories|")
        XCTAssertEqual(layout.order.firstIndex(of: .progress), layout.order.firstIndex(of: .weight)! + 1)
        XCTAssertEqual(layout.order.last, .calories)
        XCTAssertTrue(layout.visible.contains(.progress))
    }

    func testDuplicatesAreDropped() {
        let layout = TodayLayout(storage: "tip,tip,calories|")
        XCTAssertEqual(layout.order.filter { $0 == .tip }.count, 1)
    }

    func testColumnCountFollowsWidth() {
        XCTAssertEqual(TodayLayout.columnCount(fitting: 390), 1)
        XCTAssertEqual(TodayLayout.columnCount(fitting: 695), 1)
        XCTAssertEqual(TodayLayout.columnCount(fitting: 696), 2)
        XCTAssertEqual(TodayLayout.columnCount(fitting: 1024), 2)
        XCTAssertEqual(TodayLayout.columnCount(fitting: 1052), 3)
        XCTAssertEqual(TodayLayout.columnCount(fitting: 1700), 3, "Never more than three columns")
        XCTAssertEqual(TodayLayout.columnCount(fitting: 0), 1)
        XCTAssertEqual(TodayLayout.columnCount(fitting: .infinity), 1)
    }

    func testPackFillsTheShortestColumn() {
        // Calories (tall), quick actions, weight (tall), exercise, water. Alternating would put the
        // three tall cards on the left; packing sends weight to the right, beside the quick actions.
        XCTAssertEqual(TodayLayout.pack(heights: [300, 80, 200, 100, 90], into: 2, spacing: 16),
                       [0, 1, 1, 1, 0])
        XCTAssertEqual(TodayLayout.pack(heights: [300, 80, 200, 100, 90], into: 3, spacing: 16),
                       [0, 1, 2, 1, 1])
    }

    func testPackTiesGoLeftAndOneColumnTakesEverything() {
        XCTAssertEqual(TodayLayout.pack(heights: [100, 100, 100], into: 2), [0, 1, 0])
        XCTAssertEqual(TodayLayout.pack(heights: [100, 100, 100], into: 1), [0, 0, 0])
        XCTAssertEqual(TodayLayout.pack(heights: [], into: 2), [])
    }

    func testARequiredHiddenCardShowsFirst() {
        var layout = TodayLayout.default
        layout.setVisible(.exercise, false)
        XCTAssertFalse(layout.visible.contains(.exercise))
        XCTAssertEqual(layout.visible(alsoShowing: [.exercise]).first, .exercise)
        XCTAssertEqual(layout.visible(alsoShowing: []), layout.visible)
        // Already visible: kept in its place, not repeated.
        XCTAssertEqual(TodayLayout.default.visible(alsoShowing: [.exercise]), TodayLayout.default.visible)
    }
}
