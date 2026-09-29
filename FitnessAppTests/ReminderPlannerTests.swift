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

    private func plan(water: Bool = true, meals: Bool = true, waterMl: Double = 0, dayClose: Int? = nil,
                      logged: Set<MealType> = [], now: Date) -> [ReminderPlanner.Reminder] {
        ReminderPlanner.plan(settings: .init(waterEnabled: water, waterGoalMl: 2000, mealsEnabled: meals, dayCloseHour: dayClose),
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

    func testEveningCheckInWhenDinnerIsMissing() {
        let checkIn = today(plan(water: false, meals: false, dayClose: 21, logged: [.breakfast], now: at(12)))
        XCTAssertEqual(checkIn.map(\.id), ["dayclose.20260630"])
        XCTAssertEqual(checkIn.first?.date, at(21))
        XCTAssertTrue(today(plan(water: false, meals: false, dayClose: 21, logged: [.dinner], now: at(12))).isEmpty)
    }

    func testEveningCheckInDefersToAnEarlierDinnerReminder() {
        // Dinner reminder at 19:30; a check-in at 20:00 would repeat it, one at 21:00 wouldn't.
        XCTAssertFalse(today(plan(water: false, dayClose: 20, now: at(12))).contains { $0.id.hasPrefix("dayclose") })
        XCTAssertTrue(today(plan(water: false, dayClose: 21, now: at(12))).contains { $0.id.hasPrefix("dayclose") })
    }

    func testProteinCheckWhenWellShort() {
        let settings = ReminderPlanner.Settings(waterEnabled: false, waterGoalMl: 2000, mealsEnabled: false, proteinHour: 17)
        let short = ReminderPlanner.plan(settings: settings,
                                         today: .init(waterMl: 0, loggedMeals: [.lunch], proteinShortG: 40, proteinIdea: "Greek yogurt"),
                                         now: at(12), calendar: calendar)
        XCTAssertEqual(short.map(\.id), ["protein.20260630"])
        XCTAssertEqual(short.first?.date, at(17))
        XCTAssertTrue(short.first?.body.contains("Greek yogurt") ?? false)
        let nearly = ReminderPlanner.plan(settings: settings, today: .init(waterMl: 0, loggedMeals: [], proteinShortG: 10),
                                          now: at(12), calendar: calendar)
        XCTAssertTrue(nearly.isEmpty)
        XCTAssertTrue(ReminderPlanner.plan(settings: settings, today: .init(waterMl: 0, loggedMeals: [], proteinShortG: 40),
                                           now: at(18), calendar: calendar).isEmpty, "too late today")
    }

    func testProteinIdeaPicksTheLeanestFoodThatFits() {
        let foods = [(name: "Cheddar", protein: 7.0, kcal: 120.0), (name: "Greek yogurt", protein: 17.0, kcal: 100.0),
                     (name: "Chicken breast", protein: 31.0, kcal: 165.0), (name: "Almonds", protein: 6.0, kcal: 160.0)]
        XCTAssertEqual(ReminderPlanner.proteinIdea(foods: foods, shortG: 30, kcalLeft: 500), "Chicken breast")
        XCTAssertEqual(ReminderPlanner.proteinIdea(foods: foods, shortG: 30, kcalLeft: 120), "Greek yogurt")
        XCTAssertNil(ReminderPlanner.proteinIdea(foods: foods, shortG: 30, kcalLeft: 50))
    }
}
