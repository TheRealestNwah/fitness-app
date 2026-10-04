import XCTest

/// Functional iPad checks run on every PR, independently of the screenshot publishing workflow.
final class IPadSupportTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(compact: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = compact ? ["-demoData", "-compactWidth"] : ["-demoData"]
        app.launch()
        return app
    }

    private func select(_ title: String, in app: XCUIApplication) {
        let row = app.descendants(matching: .any)["sidebar-\(title)"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func testSidebarNavigationAndFoodSheet() {
        let app = launch()
        select("Food", in: app)
        let add = app.buttons["Add food"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 5))
        app.navigationBars["Log food"].buttons["Done"].tap()
        select("Settings", in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Done"].exists)
        select("Today", in: app)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-Today"].waitForExistence(timeout: 10))
    }

    func testCompactWindowUsesTabsAndCanLogFood() {
        let app = launch(compact: true)
        let food = app.tabBars.buttons["Food"]
        XCTAssertTrue(food.waitForExistence(timeout: 20))
        XCTAssertFalse(app.descendants(matching: .any)["sidebar-Today"].exists)
        food.tap()
        app.buttons["Add food"].firstMatch.tap()
        XCTAssertTrue(app.searchFields["Search foods"].waitForExistence(timeout: 5))
        app.navigationBars["Log food"].buttons["Done"].tap()
        XCTAssertTrue(food.isSelected)
    }
}
