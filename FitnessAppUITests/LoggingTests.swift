import XCTest

/// The logging flows from the original manual test plan: a searched food, a quick add, a recipe and vitals.
final class LoggingTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
        return app
    }

    private func button(beginningWith prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// Scrolls the current list until the element is on screen.
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "\(element) never came on screen")
    }

    /// Opens food search from the Food tab's first "Add food" row.
    private func openFoodSearch(in app: XCUIApplication) {
        app.tabBars.buttons["Food"].tap()
        let add = app.buttons["Add food"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 5))
    }

    private func closeFoodSearch(in app: XCUIApplication) {
        let bar = app.navigationBars["Log food"]
        // While a search is active the bar shows the search's Close button instead of Done.
        if !bar.buttons["Done"].exists, bar.buttons["Close"].exists {
            bar.buttons["Close"].tap()
        }
        XCTAssertTrue(bar.buttons["Done"].waitForExistence(timeout: 5))
        bar.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForNonExistence(timeout: 5))
    }

    private func search(_ text: String, in app: XCUIApplication) {
        let field = app.searchFields["Search foods"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
    }

    func testLoggingASearchedFoodAddsItToTheDiary() {
        let app = launch()
        openFoodSearch(in: app)
        // Not in the demo diary for today, unlike the Apple at lunch.
        search("Banana", in: app)
        let banana = button(beginningWith: "Banana, 1 medium", in: app)
        XCTAssertTrue(banana.waitForExistence(timeout: 5))
        banana.tap()
        let log = app.buttons["Log"]
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        log.tap()
        XCTAssertTrue(log.waitForNonExistence(timeout: 5))
        closeFoodSearch(in: app)

        reveal(button(beginningWith: "Banana, 1 medium", in: app), in: app)
    }

    func testQuickAddAppearsInTheDiary() {
        let app = launch()
        openFoodSearch(in: app)
        let quickAdd = app.buttons["Quick add calories"]
        reveal(quickAdd, in: app)
        quickAdd.tap()
        XCTAssertTrue(app.navigationBars["Quick add"].waitForExistence(timeout: 5))

        let name = app.textFields["Description (e.g. Restaurant pasta)"]
        name.tap()
        name.typeText("UI test pasta")
        let calories = app.textFields["Calories"]
        XCTAssertTrue(calories.exists, "Calories field should be labelled")
        calories.tap()
        calories.typeText("650")
        app.navigationBars["Quick add"].buttons["Log"].tap()
        XCTAssertTrue(app.navigationBars["Quick add"].waitForNonExistence(timeout: 5))
        closeFoodSearch(in: app)

        reveal(button(beginningWith: "UI test pasta", in: app), in: app)
    }

    func testLoggingARecipeAddsItToTheDiary() {
        let app = launch()
        openFoodSearch(in: app)
        search("smoothie", in: app)
        let recipe = button(beginningWith: "Banana protein smoothie", in: app)
        XCTAssertTrue(recipe.waitForExistence(timeout: 5))
        recipe.tap()
        XCTAssertTrue(app.navigationBars["Log recipe"].waitForExistence(timeout: 5))
        app.navigationBars["Log recipe"].buttons["Log"].tap()
        XCTAssertTrue(app.navigationBars["Log recipe"].waitForNonExistence(timeout: 5))
        closeFoodSearch(in: app)

        reveal(button(beginningWith: "Banana protein smoothie", in: app), in: app)
    }

    func testLoggingBloodPressureShowsOnVitals() {
        let app = launch()
        app.tabBars.buttons["Vitals"].tap()
        let add = app.navigationBars["Vitals"].buttons["Add reading"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.navigationBars["Log vitals"].waitForExistence(timeout: 5))

        for (field, value) in [("Systolic", "111"), ("Diastolic", "77")] {
            let input = app.textFields[field]
            XCTAssertTrue(input.exists, "\(field) field should be labelled")
            input.tap()
            input.typeText(value)
        }
        app.navigationBars["Log vitals"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Log vitals"].waitForNonExistence(timeout: 5))

        let reading = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '111/77'")).firstMatch
        XCTAssertTrue(reading.waitForExistence(timeout: 5), "The new blood pressure should be the latest reading")
    }
}
