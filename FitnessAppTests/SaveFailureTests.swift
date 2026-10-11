import XCTest
@testable import FitnessApp

@MainActor
final class SaveFailureTests: XCTestCase {
    private struct Boom: Error {}

    func testSuccessfulSaveShowsNothing() {
        let center = SaveFailureCenter()
        XCTAssertTrue(center.perform {})
        XCTAssertNil(center.failure)
    }

    func testFailedSaveShowsBannerAndReturnsFalse() {
        let center = SaveFailureCenter()
        XCTAssertFalse(center.perform { throw Boom() })
        XCTAssertNotNil(center.failure)
    }

    func testTryAgainRerunsTheSaveAndClearsTheBannerOnSuccess() {
        let center = SaveFailureCenter()
        var attempts = 0
        center.perform {
            attempts += 1
            if attempts == 1 { throw Boom() }
        }
        XCTAssertNotNil(center.failure)
        center.tryAgain()
        XCTAssertEqual(attempts, 2)
        XCTAssertNil(center.failure)
    }

    func testTryAgainKeepsBannerWhenStillFailing() {
        let center = SaveFailureCenter()
        var attempts = 0
        center.perform {
            attempts += 1
            throw Boom()
        }
        center.tryAgain()
        XCTAssertEqual(attempts, 2)
        XCTAssertNotNil(center.failure)
    }

    func testDismissClearsBanner() {
        let center = SaveFailureCenter()
        center.perform { throw Boom() }
        center.dismiss()
        XCTAssertNil(center.failure)
    }
}
