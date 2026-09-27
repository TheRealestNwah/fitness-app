import XCTest
@testable import FitnessApp

final class ReminderPlannerTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 30, hour: hour, minute: minute))!
    }

    private func plan(water: Bool = true, meals: Bool = true, waterMl: Double = 0,
                      logged: Set<MealType> = [], now: Date) -> [ReminderPlanner.Reminder] {
        ReminderPlanner.plan(settings: .init(waterEnabled: water, waterGoalMl: 2000, mealsEnabled: meals),
                             today: .init(waterMl: waterMl, loggedMeals: logged), now: now, calendar: calendar)
    }

    private func today(_ reminders: [ReminderPlanner.Reminder]) -> [ReminderPlanner.Reminder] {
        reminders.filter { calendar.isDate($0.date, inSameDayAs: at(12)) }
    }

    func testOnlyFutureRemindersAreScheduled() {
        let reminders = plan(now: at(12))
        XCTAssertTrue(reminders.allSatisfy { $0.date > at(12) })
        XCTAssertEqual(today(reminders).filter { $0.id.hasPrefix("water") }.count, 5)    // 13, 15, 17, 19, 21
    }

    func testWaterRemindersStopOnceTheGoalIsMet() {
        let reminders = plan(waterMl: 2000, now: at(12))
        XCTAssertTrue(today(reminders).allSatisfy { !$0.id.hasPrefix("water") })
        XCTAssertTrue(reminders.contains { $0.id.hasPrefix("water") }, "later days still get them")
    }

    func testLoggedMealsAreSkippedToday() {
        let reminders = today(plan(logged: [.breakfast, .lunch], now: at(7)))
        let meals = reminders.filter { $0.id.hasPrefix("meal") }.map(\.title)
        XCTAssertEqual(meals, ["Log your dinner"])
    }

    func testNudgeWhenNothingLoggedByLunch() {
        let lunch = today(plan(now: at(9))).first { $0.id.hasSuffix(".lunch") }
        XCTAssertEqual(lunch?.title, "Nothing logged yet today")
        let normal = today(plan(logged: [.breakfast], now: at(9))).first { $0.id.hasSuffix(".lunch") }
        XCTAssertEqual(normal?.title, "Log your lunch")
    }

    func testStaysWellUnderTheSystemLimit() {
        let reminders = plan(now: at(0))
        XCTAssertLessThanOrEqual(reminders.count, 60)
        XCTAssertEqual(Set(reminders.map(\.id)).count, reminders.count, "identifiers are unique")
    }

    func testNothingWhenDisabled() {
        XCTAssertTrue(plan(water: false, meals: false, now: at(8)).isEmpty)
    }
}
