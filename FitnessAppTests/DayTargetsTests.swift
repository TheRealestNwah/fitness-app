import XCTest
@testable import FitnessApp

final class DayTargetsTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func day(_ weekday: Int) -> Date {
        // 2024-01-07 is a Sunday (weekday 1).
        var comps = DateComponents(year: 2024, month: 1, day: 6 + weekday)
        comps.hour = 12
        return calendar.date(from: comps)!
    }

    private func plan(weekdays: Set<Int> = [2, 4, 6], bonus: Int = 300) -> TrainingPlan {
        TrainingPlan(enabled: true, weekdays: weekdays, fromWorkouts: false, bonusKcal: bonus, carbShiftPercent: 10)
    }

    func testWeekdayMaskRoundTrips() {
        for set in [Set<Int>(), [1], [2, 4, 6], Set(1...7)] {
            XCTAssertEqual(DayTargets.weekdays(fromMask: DayTargets.weekdayMask(set)), set)
        }
        XCTAssertEqual(DayTargets.weekdayMask(TrainingPlan.defaultWeekdays), 42)
    }

    func testDayTypeFollowsTheScheduledWeekdays() {
        let p = plan()
        XCTAssertEqual(DayTargets.dayType(on: day(2), plan: p, hasWorkout: false, calendar: calendar), .training)
        XCTAssertEqual(DayTargets.dayType(on: day(3), plan: p, hasWorkout: false, calendar: calendar), .rest)
        XCTAssertEqual(DayTargets.dayType(on: day(7), plan: p, hasWorkout: false, calendar: calendar), .rest)
    }

    func testNilWhenTurnedOff() {
        var p = plan()
        p.enabled = false
        XCTAssertNil(DayTargets.dayType(on: day(2), plan: p, hasWorkout: true, calendar: calendar))
        XCTAssertEqual(DayTargets.calorieTarget(base: 2000, type: nil, plan: p, floor: 1200), 2000)
    }

    func testAWorkoutCountsOnlyWhenEnabled() {
        var p = plan()
        XCTAssertEqual(DayTargets.dayType(on: day(3), plan: p, hasWorkout: true, calendar: calendar), .rest)
        p.fromWorkouts = true
        XCTAssertEqual(DayTargets.dayType(on: day(3), plan: p, hasWorkout: true, calendar: calendar), .training)
        XCTAssertEqual(DayTargets.dayType(on: day(3), plan: p, hasWorkout: false, calendar: calendar), .rest)
    }

    func testManualOverrideAppliesToThatDayOnly() {
        var p = plan()
        p.overrideDay = calendar.startOfDay(for: day(3))
        p.overrideIsTraining = true
        XCTAssertEqual(DayTargets.dayType(on: day(3), plan: p, hasWorkout: false, calendar: calendar), .training)
        XCTAssertEqual(DayTargets.dayType(on: day(5), plan: p, hasWorkout: false, calendar: calendar), .rest)
        p.overrideDay = calendar.startOfDay(for: day(2))
        p.overrideIsTraining = false
        XCTAssertEqual(DayTargets.dayType(on: day(2), plan: p, hasWorkout: false, calendar: calendar), .rest)
    }

    func testWeeklyAverageMatchesTheOverallTarget() {
        for weekdays: Set<Int> in [[2, 4, 6], [1, 2, 3, 4], [3], [1, 2, 3, 4, 5]] {
            let p = plan(weekdays: weekdays, bonus: 300)
            let total = (1...7).reduce(0) { sum, weekday in
                let type = DayTargets.dayType(on: day(weekday), plan: p, hasWorkout: false, calendar: calendar)
                return sum + DayTargets.calorieTarget(base: 2000, type: type, plan: p, floor: 1200)
            }
            // The cut is rounded to whole calories, so allow a few either way.
            XCTAssertEqual(Double(total), 14_000, accuracy: 7, "\(weekdays)")
        }
    }

    func testTrainingDaysGetTheBonusAndRestDaysTheCut() {
        let p = plan(weekdays: [2, 4, 6], bonus: 300)
        XCTAssertEqual(DayTargets.calorieTarget(base: 2000, type: .training, plan: p, floor: 1200), 2300)
        XCTAssertEqual(DayTargets.restCutKcal(p), 225)
        XCTAssertEqual(DayTargets.calorieTarget(base: 2000, type: .rest, plan: p, floor: 1200), 1775)
    }

    func testRestDayNeverDropsBelowTheFloor() {
        let p = plan(weekdays: [2, 4, 6], bonus: 600)
        XCTAssertEqual(DayTargets.calorieTarget(base: 1400, type: .rest, plan: p, floor: 1200), 1200)
        // A base already under the floor isn't raised.
        XCTAssertEqual(DayTargets.calorieTarget(base: 1100, type: .rest, plan: p, floor: 1200), 1100)
    }

    func testWorkoutOnlyPlansAssumeThreeTrainingDays() {
        var p = plan(weekdays: [], bonus: 300)
        p.fromWorkouts = true
        XCTAssertEqual(DayTargets.expectedTrainingDays(p), 3)
        XCTAssertEqual(DayTargets.restCutKcal(p), 225)
    }

    func testCarbsShiftFromFatOnTrainingDaysAndBack() {
        let p = plan()
        let training = DayTargets.split(protein: 30, carbs: 40, fat: 30, type: .training, plan: p)
        let rest = DayTargets.split(protein: 30, carbs: 40, fat: 30, type: .rest, plan: p)
        XCTAssertEqual(training.carbs, 50)
        XCTAssertEqual(training.fat, 20)
        XCTAssertEqual(rest.carbs, 30)
        XCTAssertEqual(rest.fat, 40)
        XCTAssertEqual(training.protein + training.carbs + training.fat, 100)
        XCTAssertEqual(rest.protein + rest.carbs + rest.fat, 100)
    }

    func testCarbShiftIsLimitedByTheFatThereIs() {
        var p = plan()
        p.carbShiftPercent = 15
        let split = DayTargets.split(protein: 40, carbs: 50, fat: 10, type: .training, plan: p)
        XCTAssertEqual(split.fat, 5)
        XCTAssertEqual(split.protein + split.carbs + split.fat, 100)
    }

    func testProfileUsesThePlanAndSkipsDietBreaks() {
        let profile = UserProfile(name: "T", sex: .female, birthDate: Date(timeIntervalSince1970: 0), heightCm: 165,
                                  startWeightKg: 80, goalWeightKg: 70, activityLevel: .light, weeklyLossKg: 0.5,
                                  unitSystem: .metric)
        XCTAssertNil(profile.dayType(hasWorkout: false))
        profile.trainingDaysEnabled = true
        profile.trainingWeekdayMask = 127
        XCTAssertEqual(profile.dayType(hasWorkout: false), .training)
        XCTAssertEqual(profile.trainingPlan.weekdays.count, 7)
        profile.dietBreakStart = Date.now.addingTimeInterval(-86_400)
        profile.dietBreakEnd = Date.now.addingTimeInterval(86_400 * 7)
        XCTAssertNil(profile.dayType(hasWorkout: false))
    }

    func testMacroTargetsFollowTheDayType() {
        let profile = UserProfile(name: "T", sex: .female, birthDate: Date(timeIntervalSince1970: 0), heightCm: 165,
                                  startWeightKg: 80, goalWeightKg: 70, activityLevel: .light, weeklyLossKg: 0.5,
                                  unitSystem: .metric)
        profile.trainingDaysEnabled = true
        let flat = profile.macroTargets(currentWeightKg: 80)
        let training = profile.macroTargets(currentWeightKg: 80, dayType: .training)
        let rest = profile.macroTargets(currentWeightKg: 80, dayType: .rest)
        XCTAssertGreaterThan(training.carbs, flat.carbs)
        XCTAssertLessThan(rest.carbs, flat.carbs)
        XCTAssertEqual(profile.macroTargets(currentWeightKg: 80, dayType: nil).carbs, flat.carbs, accuracy: 0.001)
    }
}
