import XCTest
@testable import FitnessApp

final class DayBudgetTests: XCTestCase {
    private func makeProfile() -> UserProfile {
        // Big enough that the targets sit well above the safety floor.
        UserProfile(name: "T", sex: .male, birthDate: Date(timeIntervalSince1970: 0), heightCm: 185,
                    startWeightKg: 100, goalWeightKg: 85, activityLevel: .moderate, weeklyLossKg: 0.5,
                    unitSystem: .metric)
    }

    /// The fourth day of the current week, so three earlier days count towards the weekly budget.
    private var midWeek: Date {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)!.start
        return Calendar.current.date(byAdding: .day, value: 3, to: start)!.addingTimeInterval(12 * 3600)
    }

    private func budget(_ profile: UserProfile, date: Date, today: Date, intake: [Date: Double] = [:],
                        exerciseKcal: Double = 0, healthCredit: Int = 0, earnBack: Int = 0) -> DayBudget {
        DayBudget.make(profile: profile, currentKg: 100, date: date, today: today, intakeByDay: intake,
                       exerciseKcal: exerciseKcal, hasWorkout: exerciseKcal > 0,
                       healthCredit: healthCredit, earnBackPercent: earnBack)
    }

    func testWeeklyBudgetMovesTheMacrosToo() {
        let profile = makeProfile()
        profile.weeklyBudgetEnabled = true
        let today = midWeek
        let daily = profile.calorieTarget(currentWeightKg: 100)
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: today)!.start
        var intake: [Date: Double] = [:]
        for offset in 0..<3 {
            intake[Calendar.current.date(byAdding: .day, value: offset, to: weekStart)!] = Double(daily + 400)
        }

        let result = budget(profile, date: today, today: today, intake: intake)

        XCTAssertLessThan(result.base, daily)
        let expected = profile.macroTargets(currentWeightKg: 100, dayType: nil, baseCalories: result.base)
        XCTAssertEqual(result.macros.carbs, expected.carbs, accuracy: 0.001)
        XCTAssertLessThan(result.macros.carbs, profile.macroTargets(currentWeightKg: 100).carbs)
    }

    func testPastDaysIgnoreWeeklyBudgetAndActivity() {
        let profile = makeProfile()
        profile.weeklyBudgetEnabled = true
        let today = midWeek
        let yesterday = today.addingTimeInterval(-86_400)

        let result = budget(profile, date: yesterday, today: today, exerciseKcal: 500, healthCredit: 300, earnBack: 100)

        XCTAssertEqual(result.base, profile.calorieTarget(currentWeightKg: 100))
        XCTAssertEqual(result.activeCredit, 0)
    }

    func testTodayAddsTheLargerActivityCredit() {
        let profile = makeProfile()
        let today = midWeek

        let result = budget(profile, date: today, today: today, exerciseKcal: 400, healthCredit: 150, earnBack: 50)

        XCTAssertEqual(result.activeCredit, 200)
        XCTAssertEqual(result.calories, result.base + 200)
    }

    func testTrainingDaysAddTheirBonus() {
        let profile = makeProfile()
        profile.trainingDaysEnabled = true
        profile.trainingWeekdayMask = 127
        let today = midWeek

        let result = budget(profile, date: today, today: today)

        XCTAssertEqual(result.dayType, .training)
        XCTAssertEqual(result.calories, result.base + profile.trainingBonusKcal)
    }
}
