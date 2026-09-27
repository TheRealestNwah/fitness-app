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
