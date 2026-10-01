import XCTest

/// The typed-entry fallback from the barcode scanner's manual test plan. The simulator has no
/// camera scanner, so the sheet is all fallback; lookups themselves need the network and stay manual.
final class BarcodeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openScanner() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData"]
        app.launch()
        let tab = app.tabBars.buttons["Food"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20))
        tab.tap()
        let add = app.buttons["Add food"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()

        let scan = app.buttons["Scan a barcode"]
        for _ in 0..<6 where !(scan.exists && scan.isHittable) {
            app.swipeUp()
        }
        scan.tap()
        XCTAssertTrue(app.navigationBars["Scan barcode"].waitForExistence(timeout: 5))
        return app
    }

    func testSimulatorOffersTypedEntry() {
        let app = openScanner()
        let notice = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Camera scanning isn't available")).firstMatch
        XCTAssertTrue(notice.exists, "Without a camera scanner the sheet should explain the fallback")
        XCTAssertTrue(app.textFields["barcodeField"].exists)
    }

    func testLookUpWaitsForAPlausibleBarcode() {
        let app = openScanner()
        let field = app.textFields["barcodeField"]
        let lookUp = app.buttons["Look up"]
        XCTAssertFalse(lookUp.isEnabled, "Nothing typed yet")

        field.tap()
        field.typeText("12345")
        XCTAssertFalse(lookUp.isEnabled, "Five digits is too short for a product barcode")

        field.typeText("67890123")
        XCTAssertTrue(lookUp.isEnabled, "Thirteen digits is an EAN-13")
    }
}
