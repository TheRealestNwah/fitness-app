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
        row.tap()
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
        open("Vitals", in: app)
        snap("ipad-13-vitals")
        open("Plan", in: app)
        snap("ipad-14-meal-planner")

        XCUIDevice.shared.orientation = .portrait
        open("Today", in: app)
        snap("ipad-15-today-portrait")
    }
}
