import XCTest

final class MacSupportTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String] = ["-demoData"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func select(_ title: String, in app: XCUIApplication) {
        let row = app.descendants(matching: .any)["sidebar-\(title)"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Missing sidebar section: \(title)")
        row.click()
    }

    func testSidebarAndSettings() {
        let app = launch()
        for (section, control) in [("Food", "Add food"), ("Weight", "Weigh in"),
                                   ("Vitals", "Add reading"), ("Plan", "Recipes")] {
            select(section, in: app)
            XCTAssertTrue(app.buttons[control].firstMatch.waitForExistence(timeout: 5))
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "mac-\(section.lowercased())"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        select("Today", in: app)
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.searchFields["Search settings"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "mac-settings"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testKeyboardLoggingAndNewWindow() {
        let app = launch()
        select("Today", in: app)
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.searchFields["Search foods"].waitForExistence(timeout: 10))
        app.buttons["Done"].firstMatch.click()
        app.typeKey("n", modifierFlags: [.command, .shift])
        let windows = app.windows
        expectation(for: NSPredicate(format: "count >= 2"), evaluatedWith: windows)
        waitForExpectations(timeout: 10)
    }

    func testOnboardingOpensWithoutDemoData() {
        let app = launch(["-resetData"])
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 15))
        app.buttons["Continue"].click()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["sidebar-Today"].exists)
    }
}
