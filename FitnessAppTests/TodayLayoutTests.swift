import XCTest
@testable import FitnessApp

final class TodayLayoutTests: XCTestCase {
    func testEmptyStorageIsTheDefault() {
        XCTAssertEqual(TodayLayout(storage: ""), .default)
        XCTAssertEqual(TodayLayout.default.visible, TodayCard.allCases)
    }

    func testStorageRoundTrips() {
        var layout = TodayLayout.default
        layout.move(fromOffsets: IndexSet(integer: 9), toOffset: 0)      // tip first
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
}
