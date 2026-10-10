import XCTest

/// Separate targets for training and rest days.
final class TrainingDaysTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTurningItOnShowsTheDayTypeOnToday() {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData"]
        app.launch()
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["dayTypeMenu"].exists, "Off by default")
        gear.tap()
        let page = app.buttons["Nutrition & targets"]
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        page.tap()
        let toggle = app.switches["trainingDaysToggle"]
        for _ in 0..<12 where !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")

        let done = app.buttons["Done"].firstMatch
        if !done.exists { app.navigationBars.buttons.firstMatch.tap() }
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.buttons["dayTypeMenu"].waitForExistence(timeout: 10))
    }
}
