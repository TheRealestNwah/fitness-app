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

        XCTAssertTrue(app.staticTexts["Nothing planned this week"].waitForExistence(timeout: 5), "Two weeks out should be empty")
        XCTAssertEqual(logButtons(in: app).count, 0)
        let autoPlan = app.buttons["Auto-plan"]
        XCTAssertTrue(autoPlan.exists, "The day should offer Auto-plan")
        autoPlan.tap()
        let fill = app.buttons["Fill empty meals"]
        XCTAssertTrue(fill.waitForExistence(timeout: 5))
        fill.tap()

        XCTAssertTrue(logButtons(in: app).firstMatch.waitForExistence(timeout: 5), "Auto-plan should add meals to log")
        XCTAssertFalse(app.staticTexts["Nothing planned this week"].exists)
    }

    func testLoggingAPlannedMealMarksItLogged() {
        let app = openPlan()
        let logs = logButtons(in: app)
        XCTAssertTrue(logs.firstMatch.waitForExistence(timeout: 5), "Demo data should plan today")
        // The list is lazy, so the number of Log buttons on screen isn't a reliable count.
        let ticks = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Logged'"))
        let before = ticks.count
        logs.firstMatch.tap()
        expectation(for: NSPredicate(format: "count > %d", before), evaluatedWith: ticks)
        waitForExpectations(timeout: 5)
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
