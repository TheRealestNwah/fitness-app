import XCTest

/// Settings flows from the original manual test plans: search, appearance, reminders and export.
final class SettingsTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches with demo data and opens the Settings sheet from Today.
    private func openSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData"]
        app.launch()
        let gear = app.buttons["openSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 20))
        gear.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        return app
    }

    private func openPage(_ title: String, in app: XCUIApplication) {
        let link = app.buttons[title]
        XCTAssertTrue(link.waitForExistence(timeout: 5), "No Settings page called \(title)")
        link.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
    }

    /// Brightness (0–1) of the window background at the left edge, halfway down the screen.
    private func backgroundBrightness(of app: XCUIApplication) -> CGFloat {
        let image = app.windows.firstMatch.screenshot().image
        guard let cg = image.cgImage else { return -1 }
        let x = 2 * Int(image.scale), y = cg.height / 2
        let space = CGColorSpaceCreateDeviceRGB()
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return -1 }
        ctx.draw(cg, in: CGRect(x: -x, y: y - cg.height + 1, width: cg.width, height: cg.height))
        return (CGFloat(pixel[0]) + CGFloat(pixel[1]) + CGFloat(pixel[2])) / (3 * 255)
    }

    /// Samples the background for up to three seconds, stopping once `done` holds.
    private func brightness(of app: XCUIApplication, settlingWhere done: (CGFloat) -> Bool) -> CGFloat {
        var value = backgroundBrightness(of: app)
        for _ in 0..<6 where !done(value) {
            Thread.sleep(forTimeInterval: 0.5)
            value = backgroundBrightness(of: app)
        }
        return value
    }

    private func choose(_ option: String, fromPicker label: String, in app: XCUIApplication) {
        let picker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "No \(label) picker")
        picker.tap()
        let item = app.buttons[option]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "No \(option) option")
        item.tap()
        let chosen = NSPredicate(format: "label CONTAINS %@", option)
        expectation(for: chosen, evaluatedWith: picker)
        waitForExpectations(timeout: 5)
    }

    func testSearchFindsAppearanceFromARelatedWord() {
        let app = openSettings()
        let search = app.searchFields["Search settings"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("dark mode")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Appearance'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(app.navigationBars["Profile & goals"].waitForExistence(timeout: 5))
    }

    func testAppearanceSwitchesImmediately() {
        let app = openSettings()
        openPage("Profile & goals", in: app)

        // The repaint can trail the picker by a frame or two, so give it a moment.
        choose("Light", fromPicker: "Appearance", in: app)
        let light = brightness(of: app, settlingWhere: { $0 > 0.8 })
        choose("Dark", fromPicker: "Appearance", in: app)
        let dark = brightness(of: app, settlingWhere: { $0 < 0.2 })
        XCTAssertGreaterThan(light, 0.8, "Light appearance should have a light background")
        XCTAssertLessThan(dark, 0.2, "Dark appearance should have a dark background")

        // Leave the simulator as we found it for later tests.
        choose("Match system", fromPicker: "Appearance", in: app)
    }

    func testTurningOnTheWeighInReminderOffersATime() {
        let app = openSettings()
        openPage("Reminders", in: app)

        let toggle = app.switches["Morning weigh-in"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.value as? String == "1" { toggle.switches.firstMatch.tap() }
        toggle.switches.firstMatch.tap()

        // The first reminder asks for notification permission.
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }

        XCTAssertEqual(toggle.value as? String, "1")
        let time = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Time'")).firstMatch
        XCTAssertTrue(time.waitForExistence(timeout: 5), "Turning the reminder on should show its time")
    }

    func testExportListsTheCSVFiles() {
        let app = openSettings()
        openPage("Health & data", in: app)

        let export = app.buttons["Export and share"]
        for _ in 0..<8 where !export.isHittable { app.swipeUp() }
        export.tap()
        XCTAssertTrue(app.navigationBars["Export"].waitForExistence(timeout: 10))
        for name in ["weight.csv", "food-log.csv", "vitals.csv", "Weekly summary image", "Health report for your doctor (PDF)"] {
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch.exists,
                          "Export sheet is missing \(name)")
        }
    }
}
