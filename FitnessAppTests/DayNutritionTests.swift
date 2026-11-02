import XCTest
@testable import FitnessApp

final class DayNutritionTests: XCTestCase {
    private let calendar = Calendar.current

    private func makeProfile() -> UserProfile {
        // Big enough that the targets sit well above the safety floor.
        UserProfile(name: "T", sex: .male, birthDate: Date(timeIntervalSince1970: 0), heightCm: 185,
                    startWeightKg: 100, goalWeightKg: 85, activityLevel: .moderate, weeklyLossKg: 0.5,
                    unitSystem: .metric)
    }

    /// Midday on the fourth day of the current week, so three earlier days count towards the weekly budget.
    private var midWeek: Date {
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)!.start
        return calendar.date(byAdding: .day, value: 3, to: start)!.addingTimeInterval(12 * 3600)
    }

    private func day(_ profile: UserProfile, _ day: Date, now: Date, food: [DayNutrition.Food] = [],
                     exercise: [DayNutrition.Workout] = [], latestKg: Double? = 96,
                     healthCredit: Int = 0, earnBack: Int = 0) -> DayNutrition {
        DayNutrition.make(profile: profile, day: day, food: food, exercise: exercise, latestWeightKg: latestKg,
                          healthCredit: healthCredit, earnBackPercent: earnBack, now: now, calendar: calendar)
    }

    func testCountsOnlyTheDaysFoodAsEaten() {
        let profile = makeProfile()
        let today = midWeek
        let food = [
            DayNutrition.Food(date: today, calories: 500, protein: 30, carbs: 50, fat: 10),
            DayNutrition.Food(date: today.addingTimeInterval(3600), calories: 250, protein: 10, carbs: 20, fat: 5),
            DayNutrition.Food(date: today.adding(days: -1), calories: 2000, protein: 100, carbs: 200, fat: 80),
        ]

        let result = day(profile, today, now: today, food: food)

        XCTAssertEqual(result.eaten, .init(calories: 750, protein: 40, carbs: 70, fat: 15))
        XCTAssertEqual(result.day, calendar.startOfDay(for: today))
        XCTAssertEqual(result.remaining.calories, Double(result.target) - 750)
        XCTAssertEqual(result.remaining.protein, result.macros.protein - 40, accuracy: 0.001)
        XCTAssertEqual(result.remaining.carbs, result.macros.carbs - 70, accuracy: 0.001)
        XCTAssertEqual(result.remaining.fat, result.macros.fat - 15, accuracy: 0.001)
    }

    func testUsesTheLatestWeighInAndFallsBackToTheStartingWeight() {
        let profile = makeProfile()
        let today = midWeek

        XCTAssertEqual(day(profile, today, now: today, latestKg: 92).weightKg, 92)
        XCTAssertEqual(day(profile, today, now: today, latestKg: 92).target, profile.calorieTarget(currentWeightKg: 92))
        XCTAssertEqual(day(profile, today, now: today, latestKg: nil).weightKg, 100)
        XCTAssertEqual(profile.currentWeightKg(latestWeighIn: nil), 100)
        XCTAssertEqual(profile.currentWeightKg(latestWeighIn: 97.5), 97.5)
    }

    func testEarlierDaysThisWeekFeedWeeklyBudgetingToday() {
        let profile = makeProfile()
        profile.weeklyBudgetEnabled = true
        let today = midWeek
        let daily = profile.calorieTarget(currentWeightKg: 96)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        let food = (0..<3).map {
            DayNutrition.Food(date: calendar.date(byAdding: .day, value: $0, to: weekStart)!.addingTimeInterval(9 * 3600),
                              calories: Double(daily + 400))
        }

        let result = day(profile, today, now: today, food: food)

        var intake: [Date: Double] = [:]
        for line in food { intake[calendar.startOfDay(for: line.date)] = line.calories }
        let expected = DayBudget.make(profile: profile, currentKg: 96, date: today, today: today, intakeByDay: intake,
                                      exerciseKcal: 0, hasWorkout: false, healthCredit: 0, earnBackPercent: 0)
        XCTAssertLessThan(result.base, daily)
        XCTAssertEqual(result.base, expected.base)
        XCTAssertEqual(result.target, expected.calories)
        XCTAssertEqual(result.eaten.calories, 0)
    }

    func testOnlyTheDaysWorkoutsCountAndOnlyTodayGetsCredit() {
        let profile = makeProfile()
        let today = midWeek
        let yesterday = today.adding(days: -1)
        let exercise = [DayNutrition.Workout(date: today, calories: 400),
                        DayNutrition.Workout(date: yesterday, calories: 2000)]

        let todays = day(profile, today, now: today, exercise: exercise, earnBack: 50)
        let past = day(profile, yesterday, now: today, exercise: exercise, healthCredit: 300, earnBack: 50)

        XCTAssertEqual(todays.activeCredit, 200)
        XCTAssertEqual(todays.target, profile.calorieTarget(currentWeightKg: 96) + 200)
        XCTAssertEqual(past.activeCredit, 0)
        XCTAssertEqual(past.target, profile.calorieTarget(currentWeightKg: 96))
    }

    func testDailyTargetLeavesOutTheDaysAdjustments() {
        let profile = makeProfile()
        let today = midWeek
        profile.trainingDaysEnabled = true
        profile.dayTypeOverrideDay = today
        profile.dayTypeOverrideIsTraining = true

        let result = day(profile, today, now: today, healthCredit: 150)
        let plain = DayNutrition.dailyTarget(profile: profile, latestWeightKg: 96)

        XCTAssertEqual(plain, profile.calorieTarget(currentWeightKg: 96))
        XCTAssertEqual(result.dayType, .training)
        XCTAssertEqual(result.target, plain + profile.trainingBonusKcal + 150)
        XCTAssertEqual(DayNutrition.dailyMacros(profile: profile, latestWeightKg: 96).protein,
                       profile.macroTargets(currentWeightKg: 96).protein, accuracy: 0.001)
        XCTAssertEqual(DayNutrition.dailyTarget(profile: profile, latestWeightKg: nil),
                       profile.calorieTarget(currentWeightKg: 100))
    }

    func testWidgetSnapshotShowsTheSameDay() {
        let profile = makeProfile()
        profile.weeklyBudgetEnabled = true
        let today = midWeek
        let earlier = today.adding(days: -2)
        let nutrition = day(profile, today, now: today,
                            food: [.init(date: today, calories: 600, protein: 35), .init(date: earlier, calories: 3500)],
                            exercise: [.init(date: today, calories: 300)], healthCredit: 100, earnBack: 50)

        let snapshot = WidgetSnapshot.make(profile: profile, food: [(today, 600), (earlier, 3500)], water: [],
                                           latestWeightKg: 96, logDates: [], protein: [(today, 35)],
                                           exercise: [(today, 300)], healthCredit: 100, earnBackPercent: 50,
                                           now: today, calendar: calendar)

        XCTAssertEqual(snapshot.targetKcal, nutrition.target)
        XCTAssertEqual(snapshot.consumedKcal, nutrition.eaten.calories)
        XCTAssertEqual(snapshot.remainingKcal, nutrition.remaining.calories)
        XCTAssertEqual(snapshot.proteinG, nutrition.eaten.protein)
        XCTAssertEqual(snapshot.proteinTargetG, nutrition.macros.protein)
    }
}
