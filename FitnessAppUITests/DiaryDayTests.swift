import XCTest

/// Moving between diary days from the original manual test plan: swipes and the calendar.
final class DiaryDayTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-demoData"]
        app.launch()
        let tab = app.tabBars.buttons["Food"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20))
        tab.tap()
        XCTAssertTrue(app.buttons["Breakfast options"].waitForExistence(timeout: 10))
    }

    override func tearDownWithError() throws {
        // The diary remembers a day picked on purpose, so leave it on today for the next test.
        let back = app.buttons["Back to today"]
        if back.exists { back.tap() }
    }

    private var backToToday: XCUIElement { app.buttons["Back to today"] }

    /// Drags across the Breakfast header, away from rows and their own swipe actions.
    private func swipeDiary(right: Bool) {
        let window = app.windows.firstMatch
        let header = app.buttons["Breakfast options"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        let dy = header.frame.midY / window.frame.height
        let left = window.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: dy))
        let rightEdge = window.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: dy))
        if right {
            left.press(forDuration: 0.05, thenDragTo: rightEdge)
        } else {
            rightEdge.press(forDuration: 0.05, thenDragTo: left)
        }
    }

    func testSwipingMovesBetweenDaysButNotPastToday() {
        swipeDiary(right: true)
        XCTAssertTrue(app.staticTexts["Yesterday"].waitForExistence(timeout: 5), "A right swipe should go back a day")
        XCTAssertTrue(backToToday.exists)

        swipeDiary(right: false)
        XCTAssertTrue(backToToday.waitForNonExistence(timeout: 5), "A left swipe should come back to today")

        swipeDiary(right: false)
        XCTAssertFalse(app.staticTexts["Tomorrow"].waitForExistence(timeout: 2), "The diary shouldn't go past today")
        XCTAssertFalse(backToToday.exists)
    }

    func testCalendarJumpsToAPickedDayAndBack() {
        app.buttons["Choose a day"].tap()
        XCTAssertTrue(app.navigationBars["Choose a day"].waitForExistence(timeout: 5))

        // Two days ago, which demo data logged; it may sit in last month's page.
        let target = Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        let day = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", formatter.string(from: target))).firstMatch
        if !Calendar.current.isDate(target, equalTo: .now, toGranularity: .month) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'previous month'")).firstMatch.tap()
        }
        XCTAssertTrue(day.waitForExistence(timeout: 5), "No calendar cell for \(formatter.string(from: target))")
        day.tap()

        XCTAssertTrue(app.navigationBars["Choose a day"].waitForNonExistence(timeout: 5), "Picking a day should close the calendar")
        XCTAssertTrue(backToToday.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Yesterday"].exists)

        app.buttons["Choose a day"].tap()
        XCTAssertTrue(app.navigationBars["Choose a day"].waitForExistence(timeout: 5))
        app.navigationBars["Choose a day"].buttons["Today"].tap()
        XCTAssertTrue(backToToday.waitForNonExistence(timeout: 5), "Today should return to today")
    }
}
