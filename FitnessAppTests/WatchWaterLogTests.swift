import XCTest
@testable import FitnessApp

final class WatchWaterLogTests: XCTestCase {
    func testRoundTripsThroughUserInfo() {
        let log = WatchWaterLog(date: Date(timeIntervalSince1970: 1_800_000_000), amountMl: 250)
        XCTAssertEqual(WatchWaterLog(userInfo: log.userInfo), log)
    }

    func testRejectsOtherMessages() {
        var info = WatchWaterLog(date: .now, amountMl: 250).userInfo
        info["kind"] = "food"
        XCTAssertNil(WatchWaterLog(userInfo: info))
        XCTAssertNil(WatchWaterLog(userInfo: [:]))
    }

    func testRejectsImplausibleAmounts() {
        for amount in [0.0, -250, 5001] {
            XCTAssertNil(WatchWaterLog(userInfo: WatchWaterLog(date: .now, amountMl: amount).userInfo), "\(amount)")
        }
        XCTAssertNotNil(WatchWaterLog(userInfo: WatchWaterLog(date: .now, amountMl: 5000).userInfo))
    }

    func testRejectsMalformedID() {
        var info = WatchWaterLog(date: .now, amountMl: 250).userInfo
        info["id"] = "not-a-uuid"
        XCTAssertNil(WatchWaterLog(userInfo: info))
    }
}
