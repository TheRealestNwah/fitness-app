import XCTest

/// Walks the main screens and attaches a screenshot of each. CI exports the
/// attachments so the PR can show what the app looks like without opening Xcode.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func snap(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8) // let animations settle
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testA_OnboardingFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetData"]
        app.launch()

        let next = app.buttons["Continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        snap("01-onboarding-welcome")

        next.tap()
        snap("02-onboarding-about-you")
        next.tap()
        snap("03-onboarding-weights")
        next.tap()
        snap("04-onboarding-lifestyle")
        next.tap()
        snap("05-onboarding-your-plan")

        let start = app.buttons["Start my journey"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        snap("06-today-first-launch")
    }

    func testB_MainScreensWithDemoData() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData"]
        app.launch()

        let tabs = app.tabBars
        XCTAssertTrue(tabs.buttons["Today"].waitForExistence(timeout: 15))
        snap("10-today")

        app.swipeUp()
        snap("11-today-scrolled")

        tabs.buttons["Food"].tap()
        snap("12-food-diary")

        app.buttons["Add food"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 5))
        snap("13-food-search")

        app.buttons["Scan a barcode"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Scan barcode"].waitForExistence(timeout: 5))
        snap("13b-barcode-scanner")
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 5))
        app.buttons["Done"].firstMatch.tap()

        tabs.buttons["Weight"].tap()
        snap("14-weight")

        app.navigationBars["Weight"].buttons["addWeighIn"].tap()
        XCTAssertTrue(app.navigationBars["Weigh in"].waitForExistence(timeout: 5))
        snap("15-weigh-in-sheet")
        app.buttons["Cancel"].firstMatch.tap()

        tabs.buttons["Vitals"].tap()
        snap("16-vitals")

        app.staticTexts["Blood pressure"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Blood pressure"].waitForExistence(timeout: 5))
        snap("17-vital-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        tabs.buttons["Plan"].tap()
        snap("18-meal-planner")

        app.buttons["Recipes"].firstMatch.tap()
        snap("19-recipes")

        app.buttons["Groceries"].firstMatch.tap()
        snap("20-grocery-list")

        tabs.buttons["Today"].tap()
        app.navigationBars["Today"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        snap("21-settings")
    }

    /// "-appearance dark" lands in UserDefaults via the argument domain, which the
    /// Appearance setting reads, so the app renders in dark mode regardless of the simulator.
    func testC_DarkMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-appearance", "dark"]
        app.launch()

        let tabs = app.tabBars
        XCTAssertTrue(tabs.buttons["Today"].waitForExistence(timeout: 15))
        snap("30-dark-today")

        tabs.buttons["Food"].tap()
        snap("31-dark-food-diary")

        tabs.buttons["Weight"].tap()
        snap("32-dark-weight")

        tabs.buttons["Vitals"].tap()
        snap("33-dark-vitals")

        tabs.buttons["Plan"].tap()
        snap("34-dark-meal-planner")

        app.buttons["Recipes"].firstMatch.tap()
        snap("35-dark-recipes")
    }

    /// The largest accessibility text size, set through the launch-argument domain so the
    /// simulator's own setting doesn't matter.
    func testD_LargestTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        let tabs = app.tabBars
        XCTAssertTrue(tabs.buttons["Today"].waitForExistence(timeout: 15))
        snap("40-ax-today")
        app.swipeUp()
        snap("41-ax-today-scrolled")

        tabs.buttons["Food"].tap()
        snap("42-ax-food-diary")

        tabs.buttons["Weight"].tap()
        snap("43-ax-weight")

        tabs.buttons["Vitals"].tap()
        snap("44-ax-vitals")

        tabs.buttons["Plan"].tap()
        snap("45-ax-meal-planner")
    }
}
