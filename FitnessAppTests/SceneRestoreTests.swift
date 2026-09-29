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

    func testTodayIsNotStoredSoItFollowsTheClock() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        XCTAssertEqual(DiaryDayRestore.stored(now.startOfDay, now: now), 0)
        let yesterday = now.startOfDay.adding(days: -1)
        XCTAssertEqual(DiaryDayRestore.stored(yesterday, now: now), yesterday.timeIntervalSinceReferenceDate)
    }

    func testSectionsRoundTripThroughSceneStorage() {
        for tab in MainTabView.Tab.allCases {
            XCTAssertEqual(MainTabView.Tab(rawValue: tab.rawValue), tab)
        }
    }
}
