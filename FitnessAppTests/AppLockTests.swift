import XCTest
@testable import FitnessApp

final class AppLockTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testNeverLocksWhenOff() {
        XCTAssertFalse(AppLock.shouldLock(enabled: false, backgroundedAt: nil, now: now, grace: .immediately))
        XCTAssertFalse(AppLock.shouldLock(enabled: false, backgroundedAt: now.addingTimeInterval(-3600), now: now, grace: .immediately))
    }

    func testLocksOnLaunch() {
        XCTAssertTrue(AppLock.shouldLock(enabled: true, backgroundedAt: nil, now: now, grace: .fiveMinutes))
    }

    func testImmediatelyLocksOnAnyReturn() {
        XCTAssertTrue(AppLock.shouldLock(enabled: true, backgroundedAt: now, now: now, grace: .immediately))
    }

    func testGracePeriod() {
        let away59 = now.addingTimeInterval(-59), away60 = now.addingTimeInterval(-60)
        XCTAssertFalse(AppLock.shouldLock(enabled: true, backgroundedAt: away59, now: now, grace: .oneMinute))
        XCTAssertTrue(AppLock.shouldLock(enabled: true, backgroundedAt: away60, now: now, grace: .oneMinute))
        XCTAssertFalse(AppLock.shouldLock(enabled: true, backgroundedAt: now.addingTimeInterval(-299), now: now, grace: .fiveMinutes))
        XCTAssertTrue(AppLock.shouldLock(enabled: true, backgroundedAt: now.addingTimeInterval(-300), now: now, grace: .fiveMinutes))
    }
}
