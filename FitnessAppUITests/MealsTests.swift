import XCTest

/// Customising the meals in Settings → Nutrition & targets → Meals.
final class MealsTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openMeals() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData"]
        app.launch()
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 20))
        gear.tap()
        let page = app.buttons["Nutrition & targets"]
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        page.tap()
        let link = app.buttons["mealsLink"]
        for _ in 0..<10 where !link.isHittable { app.swipeUp() }
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))
        return app
    }

    func testAddAMeal() {
        let app = openMeals()
        app.buttons["addMeal"].tap()
        let name = app.textFields["mealName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Brunch")
        app.buttons["saveMeal"].tap()
        XCTAssertTrue(app.buttons["mealRow-Brunch"].waitForExistence(timeout: 5))
    }

    func testRenameAMeal() {
        let app = openMeals()
        let snacks = app.buttons["mealRow-Snacks"]
        XCTAssertTrue(snacks.waitForExistence(timeout: 5))
        snacks.tap()
        let name = app.textFields["mealName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.clearText()
        name.typeText("Grazing")
        app.buttons["saveMeal"].tap()
        XCTAssertTrue(app.buttons["mealRow-Grazing"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mealRow-Snacks"].exists)
    }
}

private extension XCUIElement {
    func clearText() {
        guard let text = value as? String else { return }
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count))
    }
}
