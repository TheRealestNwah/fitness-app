import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String = ""
    var sexRaw: String = BiologicalSex.female.rawValue
    var birthDate: Date = Date(timeIntervalSince1970: 0)
    var heightCm: Double = 170
    var startWeightKg: Double = 80
    var goalWeightKg: Double = 70
    var activityLevelRaw: String = ActivityLevel.light.rawValue
    var weeklyLossKg: Double = 0.5
    var unitSystemRaw: String = UnitSystem.metric.rawValue
    var waterGoalMl: Double = 2500
    var customCalorieTarget: Int?
    var proteinPercent: Double = 30
    var carbsPercent: Double = 40
    var fatPercent: Double = 30
    var startDate: Date = Date()
    var weighInReminderEnabled: Bool = false
    var weighInReminderHour: Int = 7
    var waterReminderEnabled: Bool = false
    var mealReminderEnabled: Bool = false

    init(name: String,
         sex: BiologicalSex,
         birthDate: Date,
         heightCm: Double,
         startWeightKg: Double,
         goalWeightKg: Double,
         activityLevel: ActivityLevel,
         weeklyLossKg: Double,
         unitSystem: UnitSystem) {
        self.name = name
        self.sexRaw = sex.rawValue
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.startWeightKg = startWeightKg
        self.goalWeightKg = goalWeightKg
        self.activityLevelRaw = activityLevel.rawValue
        self.weeklyLossKg = weeklyLossKg
        self.unitSystemRaw = unitSystem.rawValue
        self.waterGoalMl = NutritionCalculator.waterGoalMl(weightKg: startWeightKg)
        self.startDate = Date()
    }

    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRaw) ?? .female }
        set { sexRaw = newValue.rawValue }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .light }
        set { activityLevelRaw = newValue.rawValue }
    }

    var unitSystem: UnitSystem {
        get { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
        set { unitSystemRaw = newValue.rawValue }
    }

    var units: Units { Units(system: unitSystem) }

    var age: Int { NutritionCalculator.age(birthDate: birthDate) }

    // MARK: - Derived targets

    func bmr(currentWeightKg: Double) -> Double {
        NutritionCalculator.bmr(sex: sex, weightKg: currentWeightKg, heightCm: heightCm, age: age)
    }

    func tdee(currentWeightKg: Double) -> Double {
        NutritionCalculator.tdee(bmr: bmr(currentWeightKg: currentWeightKg), activity: activityLevel)
    }

    /// Daily calorie budget, honouring a manual override if the user set one.
    func calorieTarget(currentWeightKg: Double) -> Int {
        if let custom = customCalorieTarget, custom > 0 { return custom }
        return NutritionCalculator.dailyCalorieTarget(tdee: tdee(currentWeightKg: currentWeightKg),
                                                       weeklyLossKg: weeklyLossKg,
                                                       sex: sex)
    }

    func macroTargets(currentWeightKg: Double) -> MacroTargets {
        NutritionCalculator.macroGrams(calories: calorieTarget(currentWeightKg: currentWeightKg),
                                       proteinPercent: proteinPercent,
                                       carbsPercent: carbsPercent,
                                       fatPercent: fatPercent)
    }
}
