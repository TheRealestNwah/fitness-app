import XCTest
@testable import FitnessApp

final class NutritionCalculatorTests: XCTestCase {
    func testBMRMifflinStJeor() {
        // 70 kg, 175 cm, 30-year-old male: 10*70 + 6.25*175 - 5*30 + 5 = 1648.75
        let male = NutritionCalculator.bmr(sex: .male, weightKg: 70, heightCm: 175, age: 30)
        XCTAssertEqual(male, 1648.75, accuracy: 0.01)
        // Same female: base - 161 = 1482.75
        let female = NutritionCalculator.bmr(sex: .female, weightKg: 70, heightCm: 175, age: 30)
        XCTAssertEqual(female, 1482.75, accuracy: 0.01)
    }

    func testTDEEUsesActivityMultiplier() {
        XCTAssertEqual(NutritionCalculator.tdee(bmr: 1500, activity: .sedentary), 1800, accuracy: 0.01)
        XCTAssertEqual(NutritionCalculator.tdee(bmr: 1500, activity: .moderate), 2325, accuracy: 0.01)
    }

    func testDailyTargetAppliesDeficit() {
        // 0.5 kg/week -> 550 kcal/day deficit
        let target = NutritionCalculator.dailyCalorieTarget(tdee: 2400, weeklyLossKg: 0.5, sex: .male)
        XCTAssertEqual(target, 1850)
    }

    func testDailyTargetNeverGoesBelowFloor() {
        XCTAssertEqual(NutritionCalculator.dailyCalorieTarget(tdee: 1500, weeklyLossKg: 1.0, sex: .female), 1200)
        XCTAssertEqual(NutritionCalculator.dailyCalorieTarget(tdee: 1500, weeklyLossKg: 1.0, sex: .male), 1500)
    }

    func testBMI() {
        let bmi = NutritionCalculator.bmi(weightKg: 70, heightCm: 175)
        XCTAssertEqual(bmi, 22.86, accuracy: 0.01)
        XCTAssertEqual(NutritionCalculator.bmiCategory(bmi), "Healthy")
        XCTAssertEqual(NutritionCalculator.bmiCategory(17), "Underweight")
        XCTAssertEqual(NutritionCalculator.bmiCategory(27), "Overweight")
        XCTAssertEqual(NutritionCalculator.bmiCategory(31), "Obese")
        XCTAssertEqual(NutritionCalculator.bmi(weightKg: 70, heightCm: 0), 0)
    }

    func testMacroGramsScaleToOneHundredPercent() {
        let m = NutritionCalculator.macroGrams(calories: 2000, proteinPercent: 30, carbsPercent: 40, fatPercent: 30)
        XCTAssertEqual(m.protein, 150, accuracy: 0.01)
        XCTAssertEqual(m.carbs, 200, accuracy: 0.01)
        XCTAssertEqual(m.fat, 66.67, accuracy: 0.01)

        // Percentages that do not sum to 100 are normalised.
        let n = NutritionCalculator.macroGrams(calories: 2000, proteinPercent: 50, carbsPercent: 50, fatPercent: 50)
        XCTAssertEqual(n.protein + n.carbs, 2000 * (2.0 / 3.0) / 4, accuracy: 0.01)
    }

    func testWaterGoalRoundsToQuarterLitre() {
        XCTAssertEqual(NutritionCalculator.waterGoalMl(weightKg: 80), 2750)
        XCTAssertEqual(NutritionCalculator.waterGoalMl(weightKg: 60), 2000)
    }

    func testProjectedGoalDate() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let date = NutritionCalculator.projectedGoalDate(currentKg: 80, goalKg: 75, weeklyLossKg: 0.5, from: start)
        XCTAssertNotNil(date)
        let days = Calendar.current.dateComponents([.day], from: start, to: date!).day
        XCTAssertEqual(days, 70)
        XCTAssertNil(NutritionCalculator.projectedGoalDate(currentKg: 70, goalKg: 75, weeklyLossKg: 0.5, from: start))
        XCTAssertNil(NutritionCalculator.projectedGoalDate(currentKg: 80, goalKg: 75, weeklyLossKg: 0, from: start))
    }

    func testMovingAverage() {
        let avg = NutritionCalculator.movingAverage([1, 2, 3, 4, 5], window: 3)
        XCTAssertEqual(avg, [1, 1.5, 2, 3, 4])
        XCTAssertEqual(NutritionCalculator.movingAverage([4, 6], window: 1), [4, 6])
    }

    func testWeeklyRateSlope() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        // Lose exactly 0.1 kg per day.
        let points = (0..<14).map { (date: start.addingTimeInterval(Double($0) * 86_400), weightKg: 90 - Double($0) * 0.1) }
        let rate = NutritionCalculator.weeklyRate(points: points)
        XCTAssertNotNil(rate)
        XCTAssertEqual(rate!, -0.7, accuracy: 0.0001)
        XCTAssertNil(NutritionCalculator.weeklyRate(points: [points[0]]))
    }

    func testBloodPressureCategories() {
        XCTAssertEqual(NutritionCalculator.bloodPressureCategory(systolic: 110, diastolic: 70), .normal)
        XCTAssertEqual(NutritionCalculator.bloodPressureCategory(systolic: 125, diastolic: 70), .elevated)
        XCTAssertEqual(NutritionCalculator.bloodPressureCategory(systolic: 132, diastolic: 70), .stage1)
        XCTAssertEqual(NutritionCalculator.bloodPressureCategory(systolic: 118, diastolic: 85), .stage1)
        XCTAssertEqual(NutritionCalculator.bloodPressureCategory(systolic: 145, diastolic: 95), .stage2)
        XCTAssertEqual(NutritionCalculator.bloodPressureCategory(systolic: 185, diastolic: 95), .crisis)
        XCTAssertEqual(NutritionCalculator.bloodPressureCategory(systolic: 85, diastolic: 55), .low)
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let dates = [today, today.addingTimeInterval(-86_400), today.addingTimeInterval(-2 * 86_400), today.addingTimeInterval(-5 * 86_400)]
        XCTAssertEqual(NutritionCalculator.streak(logDates: dates, today: today, calendar: cal), 3)
        XCTAssertEqual(NutritionCalculator.streak(logDates: [today.addingTimeInterval(-86_400)], today: today, calendar: cal), 0)
        XCTAssertEqual(NutritionCalculator.streak(logDates: [], today: today, calendar: cal), 0)
    }
}

final class UnitsTests: XCTestCase {
    func testWeightRoundTrip() {
        let imperial = Units(system: .imperial)
        XCTAssertEqual(imperial.weightValue(kg: 100), 220.462, accuracy: 0.001)
        XCTAssertEqual(imperial.kg(fromDisplayWeight: 220.462), 100, accuracy: 0.001)
        XCTAssertEqual(imperial.weightString(kg: 80), "176.4 lb")
        XCTAssertEqual(Units(system: .metric).weightString(kg: 80), "80.0 kg")
        XCTAssertEqual(Units(system: .metric).weightString(kg: -1.5, signed: true), "-1.5 kg")
        XCTAssertEqual(Units(system: .metric).weightString(kg: 1.5, signed: true), "+1.5 kg")
    }

    func testHeightFormatting() {
        XCTAssertEqual(Units(system: .metric).heightString(cm: 175), "175 cm")
        XCTAssertEqual(Units(system: .imperial).heightString(cm: 175), "5′ 9″")
        XCTAssertEqual(Units.cm(feet: 5, inches: 9), 175.26, accuracy: 0.01)
    }

    func testVolumeFormatting() {
        XCTAssertEqual(Units(system: .metric).volumeString(ml: 750), "750 ml")
        XCTAssertEqual(Units(system: .metric).volumeString(ml: 2500), "2.5 L")
        XCTAssertEqual(Units(system: .imperial).volumeString(ml: 2500), "85 fl oz")
    }
}

final class HealthImportRulesTests: XCTestCase {
    func testNewSamplesSkipsOwnWritesAndKnownIDs() {
        let known = UUID(), fresh = UUID(), mine = UUID()
        let samples = [
            HealthQuantitySample(id: known, date: .now, value: 80, fromThisApp: false),
            HealthQuantitySample(id: fresh, date: .now, value: 81, fromThisApp: false),
            HealthQuantitySample(id: mine, date: .now, value: 82, fromThisApp: true),
        ]
        let result = HealthImportRules.newSamples(samples, existingIDs: [known.uuidString])
        XCTAssertEqual(result.map(\.id), [fresh])
    }

    func testSleepHoursAttributedToWakeDay() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let bedtime = cal.date(byAdding: .hour, value: -1, to: today)!      // 23:00 yesterday
        let wake = cal.date(byAdding: .hour, value: 6, to: today)!           // 06:00 today
        let nap = cal.date(byAdding: .hour, value: 14, to: today)!
        let intervals = [
            HealthSleepInterval(start: bedtime, end: cal.date(byAdding: .hour, value: 2, to: today)!),
            HealthSleepInterval(start: cal.date(byAdding: .hour, value: 2, to: today)!, end: wake),
            HealthSleepInterval(start: nap, end: cal.date(byAdding: .minute, value: 30, to: nap)!),
        ]
        let hours = HealthImportRules.sleepHoursByNight(intervals, calendar: cal)
        XCTAssertEqual(hours[today]!, 7.5, accuracy: 0.001)
        XCTAssertEqual(hours.count, 1)
    }

    func testLatestPerDayAndCredit() {
        let cal = Calendar.current
        let day = cal.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let early = HealthQuantitySample(id: UUID(), date: cal.date(byAdding: .hour, value: 7, to: day)!, value: 62, fromThisApp: false)
        let late = HealthQuantitySample(id: UUID(), date: cal.date(byAdding: .hour, value: 9, to: day)!, value: 60, fromThisApp: false)
        let latest = HealthImportRules.latestPerDay([late, early], calendar: cal)
        XCTAssertEqual(latest[day]?.value, 60)
        XCTAssertEqual(HealthImportRules.activeEnergyCredit(activeKcal: 420, percent: 50), 210)
        XCTAssertEqual(HealthImportRules.activeEnergyCredit(activeKcal: 420, percent: 0), 0)
        XCTAssertEqual(HealthImportRules.vitalsSourceID(for: day, calendar: cal).hasPrefix("health:"), true)
    }
}

final class OpenFoodFactsParserTests: XCTestCase {
    func testNormaliseBarcode() {
        XCTAssertEqual(OpenFoodFactsClient.normalise(" 5000 159 484 695 "), "5000159484695")
        XCTAssertNil(OpenFoodFactsClient.normalise("12"))
        XCTAssertNil(OpenFoodFactsClient.normalise("abc"))
    }

    func testParsesPerServingValuesWhenPresent() throws {
        let json = """
        {"status":1,"code":"5000159484695","product":{"product_name":"Test Bar","brands":"Acme, Other",
         "serving_size":"45 g","serving_quantity":45,
         "nutriments":{"energy-kcal_100g":450,"energy-kcal_serving":202.5,"proteins_serving":9,
                       "carbohydrates_serving":"25.5","fat_serving":7,"fiber_serving":3}}}
        """
        let p = try XCTUnwrap(try OpenFoodFactsClient.parse(Data(json.utf8), barcode: "5000159484695"))
        XCTAssertEqual(p.name, "Test Bar")
        XCTAssertEqual(p.brand, "Acme")
        XCTAssertEqual(p.servingDescription, "45 g")
        XCTAssertEqual(p.calories, 202.5, accuracy: 0.001)
        XCTAssertEqual(p.carbs, 25.5, accuracy: 0.001)
    }

    func testScalesPer100gByServingQuantity() throws {
        let json = """
        {"status":1,"product":{"product_name":"Yogurt","serving_size":"150 g","serving_quantity":"150",
         "nutriments":{"energy-kj_100g":251.04,"proteins_100g":10,"carbohydrates_100g":4,"fat_100g":0.2}}}
        """
        let p = try XCTUnwrap(try OpenFoodFactsClient.parse(Data(json.utf8), barcode: "1234567"))
        XCTAssertEqual(p.servingDescription, "150 g")
        XCTAssertEqual(p.calories, 90, accuracy: 0.1)      // 60 kcal/100 g × 1.5
        XCTAssertEqual(p.protein, 15, accuracy: 0.001)
    }

    func testFallsBackTo100gAndHandlesUnknown() throws {
        let json = """
        {"status":1,"product":{"product_name":"Rice","nutriments":{"energy-kcal_100g":130,"proteins_100g":2.7}}}
        """
        let p = try XCTUnwrap(try OpenFoodFactsClient.parse(Data(json.utf8), barcode: "1234567"))
        XCTAssertEqual(p.servingDescription, "100 g")
        XCTAssertEqual(p.calories, 130)
        XCTAssertNil(try OpenFoodFactsClient.parse(Data("{\"status\":0}".utf8), barcode: "1234567"))
        XCTAssertThrowsError(try OpenFoodFactsClient.parse(Data("not json".utf8), barcode: "1234567"))
    }
}

final class AdaptiveTargetTests: XCTestCase {
    private let cal = Calendar.current
    private var today: Date { cal.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000)) }
    private func day(_ offset: Int, hour: Int = 12) -> Date {
        cal.date(byAdding: .hour, value: hour, to: cal.date(byAdding: .day, value: offset, to: today)!)!
    }

    func testMaintenanceFromIntakeAndWeightChange() {
        // 1500 kcal a day while losing 0.5 kg a week means maintenance is about 2050.
        let logs = (-28...(-1)).map { WeeklyReviewCalculator.FoodDay(date: day($0), calories: 1500) }
        let weights = (-28...(-1)).map { offset -> WeeklyReviewCalculator.WeightDay in
            let daysFromStart = Double(offset + 28)
            return .init(date: day(offset, hour: 7), weightKg: 84 - daysFromStart * (0.5 / 7))
        }
        let e = AdaptiveTargetCalculator.estimate(foodLogs: logs, weights: weights, today: today, calendar: cal)
        XCTAssertNotNil(e)
        XCTAssertEqual(e!.maintenanceKcal, 2050, accuracy: 2)
        XCTAssertEqual(e!.confidence, .high)
        XCTAssertEqual(e!.suggestedTarget(weeklyLossKg: 0.5, sex: .female), 1500, accuracy: 2)
        XCTAssertEqual(e!.suggestedTarget(weeklyLossKg: 1.0, sex: .female), 1200) // floored
    }

    func testRequiresEnoughData() {
        let fewLogs = (-10...(-1)).map { WeeklyReviewCalculator.FoodDay(date: day($0), calories: 1500) }
        let weights = (-28...(-1)).map { WeeklyReviewCalculator.WeightDay(date: day($0, hour: 7), weightKg: 80) }
        XCTAssertNil(AdaptiveTargetCalculator.estimate(foodLogs: fewLogs, weights: weights, today: today, calendar: cal))

        let logs = (-28...(-1)).map { WeeklyReviewCalculator.FoodDay(date: day($0), calories: 1500) }
        let clusteredWeighIns = (-4...(-1)).map { WeeklyReviewCalculator.WeightDay(date: day($0, hour: 7), weightKg: 80) }
        XCTAssertNil(AdaptiveTargetCalculator.estimate(foodLogs: logs, weights: clusteredWeighIns, today: today, calendar: cal))
    }

    func testIgnoresDataOutsideWindow() {
        var logs = (-28...(-1)).map { WeeklyReviewCalculator.FoodDay(date: day($0), calories: 1600) }
        logs.append(.init(date: day(-40), calories: 9000))
        logs.append(.init(date: day(0), calories: 9000))
        let weights = (-28...(-1)).map { WeeklyReviewCalculator.WeightDay(date: day($0, hour: 7), weightKg: 80) }
        let e = AdaptiveTargetCalculator.estimate(foodLogs: logs, weights: weights, today: today, calendar: cal)!
        XCTAssertEqual(e.meanIntakeKcal, 1600, accuracy: 0.001)
        XCTAssertEqual(e.maintenanceKcal, 1600)
    }
}

final class WeeklyReviewTests: XCTestCase {
    private let cal = Calendar.current
    private var today: Date { cal.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000)) }
    private func day(_ offset: Int, hour: Int = 12) -> Date {
        cal.date(byAdding: .hour, value: hour, to: cal.date(byAdding: .day, value: offset, to: today)!)!
    }

    func testCountsOnlyCompleteDaysInWindow() {
        var logs: [WeeklyReviewCalculator.FoodDay] = []
        for offset in -7...(-1) { logs.append(.init(date: day(offset), calories: 1500)) }
        logs.append(.init(date: day(0), calories: 900))     // today: excluded
        logs.append(.init(date: day(-8), calories: 3000))   // before window: excluded
        let r = WeeklyReviewCalculator.review(foodLogs: logs, weights: [], budget: 1600, plannedWeeklyLossKg: 0.5, today: today, calendar: cal)
        XCTAssertEqual(r.daysLogged, 7)
        XCTAssertEqual(r.averageIntake!, 1500, accuracy: 0.001)
        XCTAssertNil(r.weightChangeKg)
        XCTAssertEqual(r.headline, "Intake on budget")
    }

    func testWeightChangeComparesWindowMeans() {
        var weights: [WeeklyReviewCalculator.WeightDay] = []
        for offset in -14...(-8) { weights.append(.init(date: day(offset, hour: 7), weightKg: 82.0)) }
        for offset in -7...(-1) { weights.append(.init(date: day(offset, hour: 7), weightKg: 81.4)) }
        let logs = (-7...(-1)).map { WeeklyReviewCalculator.FoodDay(date: day($0), calories: 1550) }
        let r = WeeklyReviewCalculator.review(foodLogs: logs, weights: weights, budget: 1555, plannedWeeklyLossKg: 0.5, today: today, calendar: cal)
        XCTAssertEqual(r.weightChangeKg!, -0.6, accuracy: 0.0001)
        XCTAssertTrue(r.headline.hasPrefix("On track"), r.headline)
    }

    func testAdviceRulesInPriorityOrder() {
        XCTAssertEqual(WeeklyReviewCalculator.advice(daysLogged: 0, averageIntake: nil, budget: 1600, weightChange: nil, planned: 0.5).headline,
                       "Nothing logged in the last 7 days")
        XCTAssertEqual(WeeklyReviewCalculator.advice(daysLogged: 2, averageIntake: 1500, budget: 1600, weightChange: -0.5, planned: 0.5).headline,
                       "Only 2 of 7 days logged")
        XCTAssertEqual(WeeklyReviewCalculator.advice(daysLogged: 6, averageIntake: 1900, budget: 1600, weightChange: -0.5, planned: 0.5).headline,
                       "Averaging 300 kcal over budget")
        XCTAssertEqual(WeeklyReviewCalculator.advice(daysLogged: 6, averageIntake: 700, budget: 1600, weightChange: -0.5, planned: 0.5).headline,
                       "Logged intake looks incomplete")
        XCTAssertTrue(WeeklyReviewCalculator.advice(daysLogged: 6, averageIntake: 1550, budget: 1600, weightChange: -1.2, planned: 0.5).headline.hasPrefix("Losing faster"))
        XCTAssertTrue(WeeklyReviewCalculator.advice(daysLogged: 6, averageIntake: 1550, budget: 1600, weightChange: 0.6, planned: 0.5).headline.hasPrefix("Weight up"))
        XCTAssertEqual(WeeklyReviewCalculator.advice(daysLogged: 6, averageIntake: 1550, budget: 1600, weightChange: -0.1, planned: 0.5).headline,
                       "Intake on budget, scale moving slowly")
    }
}

final class SavedMealTests: XCTestCase {
    func testTotalsSumItems() {
        let meal = SavedMeal(name: "Test", mealType: .lunch, items: [
            SavedMealItem(foodName: "A", servings: 1, servingDescription: "x", calories: 300, protein: 20, carbs: 30, fat: 10),
            SavedMealItem(foodName: "B", servings: 2, servingDescription: "y", calories: 100, protein: 5, carbs: 10, fat: 2),
        ])
        XCTAssertEqual(meal.totalCalories, 400, accuracy: 0.001)
        XCTAssertEqual(meal.totalProtein, 25, accuracy: 0.001)
        XCTAssertEqual(meal.totalCarbs, 40, accuracy: 0.001)
        XCTAssertEqual(meal.totalFat, 12, accuracy: 0.001)
        XCTAssertEqual(meal.summary, "A, B")
    }

    func testItemSnapshotsDiaryEntry() {
        let entry = FoodLogEntry(date: .now, mealType: .dinner, foodName: "Salmon", servings: 1.5,
                                 servingDescription: "100 g", calories: 309, protein: 33, carbs: 0, fat: 18)
        let item = SavedMealItem(entry: entry)
        XCTAssertEqual(item.foodName, "Salmon")
        XCTAssertEqual(item.servings, 1.5)
        XCTAssertEqual(item.calories, 309)
    }

    func testLogDateUsesNowForTodayAndTypicalHourOtherwise() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        XCTAssertLessThan(abs(MealType.lunch.logDate(on: today).timeIntervalSinceNow), 5)
        let lastWeek = today.addingTimeInterval(-7 * 86_400)
        let stamped = MealType.dinner.logDate(on: lastWeek)
        XCTAssertTrue(cal.isDate(stamped, inSameDayAs: lastWeek))
        XCTAssertEqual(cal.component(.hour, from: stamped), 19)
    }
}

final class RecipeTests: XCTestCase {
    func testPerServingValuesDivideByServings() {
        let recipe = Recipe(name: "Test", mealType: .dinner, servings: 4, prepMinutes: 10,
                            ingredients: [
                                Ingredient(name: "A", amount: "1", calories: 400, protein: 40, carbs: 20, fat: 8),
                                Ingredient(name: "B", amount: "1", calories: 200, protein: 0, carbs: 40, fat: 4),
                            ],
                            instructions: "")
        XCTAssertEqual(recipe.caloriesPerServing, 150, accuracy: 0.001)
        XCTAssertEqual(recipe.proteinPerServing, 10, accuracy: 0.001)
        XCTAssertEqual(recipe.carbsPerServing, 15, accuracy: 0.001)
        XCTAssertEqual(recipe.fatPerServing, 3, accuracy: 0.001)
    }

    func testSeedRecipesHaveSensibleCalories() {
        for recipe in SeedData.recipes {
            XCTAssertGreaterThan(recipe.caloriesPerServing, 100, recipe.name)
            XCTAssertLessThan(recipe.caloriesPerServing, 900, recipe.name)
            XCTAssertFalse(recipe.ingredients.isEmpty, recipe.name)
        }
        XCTAssertGreaterThan(SeedData.foods.count, 80)
    }
}
