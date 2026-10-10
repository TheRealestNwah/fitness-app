import XCTest
@testable import FitnessApp

final class NumberPrivacyTests: XCTestCase {
    override func setUp() {
        NumberPrivacy.shared.manual = false
        NumberPrivacy.shared.focus = false
        UserDefaults.standard.set(EnergyUnit.kcal.rawValue, forKey: EnergyUnit.storageKey)
    }

    override func tearDown() {
        NumberPrivacy.shared.manual = false
        NumberPrivacy.shared.focus = false
    }

    func testNumbersShowByDefault() {
        XCTAssertEqual(Energy.string(1200), "1200 kcal")
        XCTAssertEqual(Energy.number(1200), "1200")
        XCTAssertEqual(Units(system: .metric).weightString(kg: 80), "80.0 kg")
    }

    func testEitherSwitchHidesCalorieAndWeightNumbers() {
        for turnOn in [{ NumberPrivacy.shared.manual = true }, { NumberPrivacy.shared.focus = true }] {
            NumberPrivacy.shared.manual = false
            NumberPrivacy.shared.focus = false
            turnOn()
            XCTAssertTrue(NumberPrivacy.shared.isOn)
            XCTAssertEqual(Energy.string(1200), NumberPrivacy.mask)
            XCTAssertEqual(Energy.number(1200), NumberPrivacy.mask)
            XCTAssertEqual(Units(system: .metric).weightString(kg: 80), NumberPrivacy.mask)
            XCTAssertEqual(Units(system: .imperial, weight: .st).weightString(kg: 80, signed: true), NumberPrivacy.mask)
            XCTAssertEqual(NumberPrivacy.hide("420"), NumberPrivacy.mask)
        }
    }

    func testEndingAFocusKeepsTheManualSetting() {
        NumberPrivacy.shared.manual = true
        NumberPrivacy.shared.focus = true
        NumberPrivacy.shared.focus = false
        XCTAssertTrue(NumberPrivacy.shared.isOn)
        NumberPrivacy.shared.manual = false
        XCTAssertFalse(NumberPrivacy.shared.isOn)
    }

    func testSettingsPersist() {
        NumberPrivacy.shared.manual = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: NumberPrivacy.manualKey))
    }

    func testProteinCheckIsMutedAndMealWordingAvoidsCalories() {
        let settings = ReminderPlanner.Settings(waterEnabled: false, waterGoalMl: 2500, mealsEnabled: true,
                                                proteinHour: 17, hideNumbers: true)
        let today = ReminderPlanner.Today(waterMl: 0, loggedMeals: [], proteinShortG: 60)
        let now = Calendar.current.startOfDay(for: .now)
        let reminders = ReminderPlanner.plan(settings: settings, today: today, now: now)
        XCTAssertFalse(reminders.contains { $0.id.hasPrefix("protein") })
        XCTAssertFalse(reminders.contains { $0.body.localizedCaseInsensitiveContains("calorie") })
        var visible = settings
        visible.hideNumbers = false
        XCTAssertTrue(ReminderPlanner.plan(settings: visible, today: today, now: now).contains { $0.id.hasPrefix("protein") })
    }
}
