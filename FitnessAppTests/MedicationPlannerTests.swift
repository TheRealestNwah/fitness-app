import SwiftData
import XCTest
@testable import FitnessApp

final class MedicationPlannerTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func day(_ d: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: d, hour: hour))!
    }

    func testNextDoseIsOneIntervalAfterTheLast() {
        XCTAssertEqual(MedicationPlanner.nextDose(after: day(1, hour: 20), intervalDays: 7, calendar: calendar),
                       calendar.startOfDay(for: day(8)))
        XCTAssertEqual(MedicationPlanner.nextDose(after: nil, intervalDays: 7, now: day(3), calendar: calendar),
                       calendar.startOfDay(for: day(3)))
    }

    func testCountdown() {
        let due = day(10)
        XCTAssertEqual(MedicationPlanner.countdown(due, now: day(10, hour: 18), calendar: calendar), "Due today")
        XCTAssertEqual(MedicationPlanner.countdown(due, now: day(9), calendar: calendar), "Due tomorrow")
        XCTAssertEqual(MedicationPlanner.countdown(due, now: day(6), calendar: calendar), "Due in 4 days")
        XCTAssertEqual(MedicationPlanner.countdown(due, now: day(13), calendar: calendar), "Overdue by 3 days")
    }

    func testSitesRotateAndWrapAround() {
        XCTAssertEqual(MedicationPlanner.nextSite(after: nil), .abdomenLeft)
        XCTAssertEqual(MedicationPlanner.nextSite(after: .abdomenLeft), .abdomenRight)
        XCTAssertEqual(MedicationPlanner.nextSite(after: .armRight), .abdomenLeft)
    }

    func testWeightChangeSinceStarting() {
        let weights = [(date: day(1), kg: 101.0), (date: day(3), kg: 100.0), (date: day(20), kg: 97.5)]
        XCTAssertEqual(MedicationPlanner.weightChange(since: day(4), weights: weights), -2.5)
        // Started before the first weigh-in: measured from that first one.
        XCTAssertEqual(MedicationPlanner.weightChange(since: day(0, hour: 0), weights: weights), -3.5)
        XCTAssertNil(MedicationPlanner.weightChange(since: day(25), weights: weights))
    }

    func testRecognisesGLP1Names() {
        XCTAssertTrue(MedicationPlanner.isGLP1("Semaglutide 2.4 MG/0.75ML Auto-Injector"))
        XCTAssertTrue(MedicationPlanner.isGLP1("My Mounjaro"))
        XCTAssertFalse(MedicationPlanner.isGLP1("Metformin 500 MG"))
    }

    func testDoseReminderOnTheDueDayOnly() {
        var settings = ReminderPlanner.Settings(waterEnabled: false, waterGoalMl: 2000, mealsEnabled: false)
        settings.medicationDue = calendar.startOfDay(for: day(12))
        settings.medicationHour = 9
        settings.medicationName = "Semaglutide (Wegovy)"
        let reminders = ReminderPlanner.plan(settings: settings, today: .init(waterMl: 0, loggedMeals: []),
                                             now: day(10, hour: 8), calendar: calendar)
        XCTAssertEqual(reminders.map(\.id), ["medication.20260612"])
        XCTAssertEqual(reminders.first?.date, day(12))
    }

    func testOverdueDoseIsRemindedToday() {
        var settings = ReminderPlanner.Settings(waterEnabled: false, waterGoalMl: 2000, mealsEnabled: false)
        settings.medicationDue = calendar.startOfDay(for: day(5))
        settings.medicationHour = 9
        let reminders = ReminderPlanner.plan(settings: settings, today: .init(waterMl: 0, loggedMeals: []),
                                             now: day(10, hour: 8), calendar: calendar)
        XCTAssertEqual(reminders.map(\.id), ["medication.20260610"])
    }

    @MainActor
    func testDoseKeepsItsSite() throws {
        let container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let dose = MedicationDose(date: day(1), medication: "Tirzepatide (Zepbound)", doseMg: 5, site: .thighLeft,
                                  sideEffects: ["Nausea"])
        container.mainContext.insert(dose)
        try container.mainContext.save()
        XCTAssertEqual(dose.site, .thighLeft)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<MedicationDose>()).first?.sideEffects, ["Nausea"])
    }
}
