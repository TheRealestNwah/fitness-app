import XCTest

/// The meal shortcuts from the original manual test plan: copy from yesterday and favourite meals.
final class FavouritesTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches with demo data and opens today's food diary. Today has breakfast, lunch and a
    /// snack logged but no dinner; yesterday had all four.
    private func openDiary() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData"]
        app.launch()
        let tab = app.tabBars.buttons["Food"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20))
        tab.tap()
        XCTAssertTrue(app.buttons["Breakfast options"].waitForExistence(timeout: 10))
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

    func testCopyFromYesterdayFillsAnEmptyMeal() {
        let app = openDiary()
        XCTAssertFalse(button(beginningWith: "Chicken stir-fry with rice", in: app).exists)

        let options = app.buttons["Dinner options"]
        reveal(options, in: app)
        options.tap()
        let copy = app.buttons["Copy from yesterday"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertTrue(copy.isEnabled, "Yesterday's dinner was logged, so copying should be offered")
        copy.tap()

        reveal(button(beginningWith: "Chicken stir-fry with rice", in: app), in: app)
    }

    func testSavedFavouriteCanBeLoggedFromSearch() {
        let app = openDiary()
        app.buttons["Breakfast options"].tap()
        let save = app.buttons["Save as favourite meal"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        let sheet = app.navigationBars["Save favourite"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        let name = app.textFields["Name (e.g. Weekday breakfast)"]
        name.tap()
        name.typeText("UI test breakfast")
        sheet.buttons["Save"].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))

        let add = app.buttons["Add food"].firstMatch
        reveal(add, in: app)
        add.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 5))
        let favourite = button(beginningWith: "UI test breakfast", in: app)
        reveal(favourite, in: app)
        favourite.tap()

        let logged = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Logged “UI test breakfast”")).firstMatch
        XCTAssertTrue(logged.waitForExistence(timeout: 5), "Tapping a favourite should log it")
    }
}
