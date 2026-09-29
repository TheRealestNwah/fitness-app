import XCTest

/// iPad screens with the sidebar layout. Skipped on iPhone; CI runs it on an iPad simulator.
final class IPadScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
    }

    private func snap(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func open(_ tab: String, in app: XCUIApplication) {
        let row = app.descendants(matching: .any)["sidebar-\(tab)"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No sidebar row for \(tab)")
        // The identifier lands on the row's icon, which XCUITest reports as not hittable; tap its centre instead.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func testSidebarScreens() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-demoData"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["sidebar-Today"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.tabBars.buttons["Today"].exists, "iPad should use the sidebar, not the tab bar")
        snap("ipad-10-today")
        open("Food", in: app)
        snap("ipad-11-food-diary")
        open("Weight", in: app)
        snap("ipad-12-weight")
        let row = app.buttons.matching(identifier: "weighInRow").firstMatch
        if row.waitForExistence(timeout: 5) {
            row.tap()
            snap("ipad-12b-weigh-in-detail")
        }
        open("Vitals", in: app)
        snap("ipad-13-vitals")
        open("Plan", in: app)
        snap("ipad-14-meal-planner")
        app.buttons["Recipes"].firstMatch.tap()
        snap("ipad-14b-recipes")
        let recipe = app.buttons.matching(identifier: "recipeRow").firstMatch
        if recipe.waitForExistence(timeout: 5) {
            recipe.tap()
            snap("ipad-14c-recipe-detail")
        }

        open("Settings", in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5), "Settings should open in the detail column")
        XCTAssertFalse(app.buttons["Done"].exists, "Settings in the sidebar isn't a sheet")
        snap("ipad-16-settings")

        open("Today", in: app)
        XCUIDevice.shared.orientation = .portrait
        snap("ipad-15-today-portrait")
    }

    /// Split View / Slide Over: a compact-width iPad window uses the tab bar.
    func testCompactWidthUsesTheTabBar() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-compactWidth"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20), "compact width should use the tab bar")
        XCTAssertFalse(app.descendants(matching: .any)["sidebar-Today"].exists)
        snap("ipad-20-compact-today")
        app.tabBars.buttons["Food"].tap()
        snap("ipad-21-compact-food")
        app.tabBars.buttons["Plan"].tap()
        snap("ipad-22-compact-plan")
    }

    /// Going from full screen into Split View mid-session keeps the section and an open sheet.
    func testSwitchingToCompactKeepsSectionAndSheet() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-flipWidthAfter", "12"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["sidebar-Food"].waitForExistence(timeout: 20))
        open("Food", in: app)
        let addFood = app.buttons["Add food"].firstMatch
        XCTAssertTrue(addFood.waitForExistence(timeout: 5))
        addFood.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 5))

        // The width flips to compact about 12 s after launch.
        let foodTab = app.tabBars.buttons["Food"]
        XCTAssertTrue(foodTab.waitForExistence(timeout: 20), "should switch to the tab bar")
        snap("ipad-23-switched-to-compact")
        XCTAssertTrue(foodTab.isSelected, "the selected section should carry over")
        XCTAssertTrue(app.navigationBars["Log food"].exists, "the open sheet should survive the switch")
    }
}
