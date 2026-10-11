import XCTest

/// Quick checks of the core flows, run on every pull request.
final class SmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20) ||
                      app.buttons["Continue"].waitForExistence(timeout: 1))
        return app
    }

    /// Scrolls the main view until the element is on screen.
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "\(element) never came on screen")
    }

    func testOnboardingReachesToday() {
        let app = launch(["-resetData"])
        let next = app.buttons["Continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        next.tap()      // welcome
        next.tap()      // about you
        XCTAssertFalse(next.isEnabled, "nothing is chosen for the person, so they pick a goal first")
        app.buttons["goal-lose"].tap()
        let goal = app.textFields["goalWeightField"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        goal.tap()
        goal.typeText("70")
        next.tap()      // weights
        next.tap()      // activity and pace
        XCTAssertTrue(app.staticTexts["Daily gap"].waitForExistence(timeout: 5))
        let start = app.buttons["Start my journey"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        // A new profile gets one clear next step and the short starter layout.
        XCTAssertTrue(app.buttons["logFirstMeal"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Fasting"].exists)
    }

    func testOnboardingWithoutAWeightGoal() {
        let app = launch(["-resetData"])
        let next = app.buttons["Continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        next.tap()      // welcome
        next.tap()      // about you
        app.buttons["goal-steady"].tap()
        XCTAssertFalse(app.textFields["goalWeightField"].exists, "keeping steady doesn't ask for a goal weight")
        next.tap()      // weights
        next.tap()      // activity, with no pace to pick
        XCTAssertTrue(app.staticTexts["Weight to hold"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Daily gap"].exists)
        app.buttons["Start my journey"].tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
    }

    func testAddingAGlassUpdatesTodaysWater() {
        let app = launch(["-demoData"])
        let total = app.staticTexts["waterTotal"]
        let add = app.buttons["addGlass"]
        reveal(add, in: app)
        let before = total.label
        add.tap()
        let changed = NSPredicate(format: "label != %@", before)
        expectation(for: changed, evaluatedWith: total)
        waitForExpectations(timeout: 5)
    }

    func testWeighInAddsAnEntry() {
        let app = launch(["-demoData"])
        app.tabBars.buttons["Weight"].tap()
        let rows = app.buttons.matching(identifier: "weighInRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        let before = rows.count

        app.navigationBars["Weight"].buttons["addWeighIn"].tap()
        XCTAssertTrue(app.navigationBars["Weigh in"].waitForExistence(timeout: 5))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Weigh in"].waitForNonExistence(timeout: 5))

        let grew = NSPredicate(format: "count == %d", before + 1)
        expectation(for: grew, evaluatedWith: rows)
        waitForExpectations(timeout: 5)
    }
}
