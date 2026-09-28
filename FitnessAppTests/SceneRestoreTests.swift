import XCTest
@testable import FitnessApp

final class SceneRestoreTests: XCTestCase {
    func testDiaryDayIsRestoredUnlessItsInTheFuture() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let lastWeek = now.addingTimeInterval(-7 * 86_400)
        XCTAssertEqual(DiaryDayRestore.day(stored: lastWeek.timeIntervalSinceReferenceDate, now: now), lastWeek)
        let tomorrow = now.addingTimeInterval(86_400)
        XCTAssertEqual(DiaryDayRestore.day(stored: tomorrow.timeIntervalSinceReferenceDate, now: now), now)
    }

    func testSectionsRoundTripThroughSceneStorage() {
        for tab in MainTabView.Tab.allCases {
            XCTAssertEqual(MainTabView.Tab(rawValue: tab.rawValue), tab)
        }
    }
}
