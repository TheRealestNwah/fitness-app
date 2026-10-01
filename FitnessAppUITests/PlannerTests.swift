import XCTest

/// The planner flows from the original manual test plan: auto-plan, log a planned meal, groceries.
final class PlannerTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches with demo data (today and tomorrow are planned) and opens the Plan tab.
    private func openPlan() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData"]
        app.launch()
        let tab = app.tabBars.buttons["Plan"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20))
        tab.tap()
        XCTAssertTrue(app.navigationBars["Meal plan"].waitForExistence(timeout: 5))
        return app
    }

    private func logButtons(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label == 'Log'"))
    }

    func testAutoPlanFillsAnEmptyWeek() {
        let app = openPlan()
        // Two weeks ahead is past anything the demo data planned.
        for _ in 0..<2 { app.buttons["Next week"].firstMatch.tap() }

        let autoPlan = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Auto-plan '")).firstMatch
        XCTAssertTrue(autoPlan.waitForExistence(timeout: 5), "An empty week should offer Auto-plan")
        XCTAssertEqual(logButtons(in: app).count, 0)
        autoPlan.tap()

        XCTAssertTrue(logButtons(in: app).firstMatch.waitForExistence(timeout: 5), "Auto-plan should add meals to log")
        XCTAssertFalse(app.staticTexts["Nothing planned this week"].exists)
    }

    func testLoggingAPlannedMealMarksItLogged() {
        let app = openPlan()
        let logs = logButtons(in: app)
        XCTAssertTrue(logs.firstMatch.waitForExistence(timeout: 5), "Demo data should plan today")
        let before = logs.count
        logs.firstMatch.tap()

        let fewer = NSPredicate(format: "count == %d", before - 1)
        expectation(for: fewer, evaluatedWith: logs)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.images["Logged"].firstMatch.exists || app.staticTexts["Logged"].firstMatch.exists)
    }

    func testGroceryListShowsThisWeeksIngredients() {
        let app = openPlan()
        app.segmentedControls.buttons["Groceries"].tap()

        let header = app.staticTexts.matching(NSPredicate(format: "label MATCHES '[0-9]+ items'")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Planned recipes should put ingredients on the list")
        XCTAssertTrue(app.buttons["Send to Reminders"].exists)

        // An empty week has nothing to buy.
        for _ in 0..<2 { app.buttons["Next week"].firstMatch.tap() }
        XCTAssertTrue(app.staticTexts["Nothing planned this week"].waitForExistence(timeout: 5))
    }
}
