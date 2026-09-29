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
    /// Set when the user switched from losing to holding weight; nil while losing.
    var maintenanceStartedAt: Date?
    /// Weight to hold and how far either side of it counts as on track.
    var maintenanceWeightKg: Double?
    var maintenanceBandKg: Double = 1.5
    /// Budget the week as a whole: lighter days bank calories for later ones.
    var weeklyBudgetEnabled: Bool = false
    /// A planned stretch at maintenance; the end day is not included.
    var dietBreakStart: Date?
    var dietBreakEnd: Date?
    var proteinPercent: Double = 30
    var carbsPercent: Double = 40
    var fatPercent: Double = 30
    /// "kg", "lb" or "st"; empty follows the unit system.
    var weightUnitRaw: String = ""
    /// Optional daily goals; nil means untracked. Fibre is a minimum, sugar and sodium are limits.
    var fiberTargetG: Double?
    var sugarLimitG: Double?
    var sodiumLimitMg: Double?
    var startDate: Date = Date()
    var weighInReminderEnabled: Bool = false
    var weighInReminderHour: Int = 7
    var waterReminderEnabled: Bool = false
    var mealReminderEnabled: Bool = false
    /// Evening check-in when dinner isn't logged; nil when off.
    var dayCloseReminderHour: Int?

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

    var units: Units { Units(system: unitSystem, weight: WeightUnit(rawValue: weightUnitRaw)) }

    var age: Int { NutritionCalculator.age(birthDate: birthDate) }

    // MARK: - Derived targets

    func bmr(currentWeightKg: Double) -> Double {
        NutritionCalculator.bmr(sex: sex, weightKg: currentWeightKg, heightCm: heightCm, age: age)
    }

    func tdee(currentWeightKg: Double) -> Double {
        NutritionCalculator.tdee(bmr: bmr(currentWeightKg: currentWeightKg), activity: activityLevel)
    }

    var isMaintaining: Bool { maintenanceStartedAt != nil }

    /// The band's centre: the weight chosen when maintenance started, else the goal.
    var maintenanceCenterKg: Double { maintenanceWeightKg ?? goalWeightKg }

    func startMaintenance(atKg weightKg: Double) {
        maintenanceStartedAt = .now
        maintenanceWeightKg = weightKg
        customCalorieTarget = nil          // the maintenance target replaces any deficit override
    }

    var isOnDietBreak: Bool { BudgetCalculator.isOnBreak(start: dietBreakStart, end: dietBreakEnd) }

    func endMaintenance() {
        maintenanceStartedAt = nil
        maintenanceWeightKg = nil
    }

    /// Daily calorie budget, honouring a manual override if the user set one.
    func calorieTarget(currentWeightKg: Double) -> Int {
        if let custom = customCalorieTarget, custom > 0 { return custom }
        if isMaintaining || isOnDietBreak {
            return MaintenanceCalculator.calorieTarget(tdee: tdee(currentWeightKg: currentWeightKg), sex: sex)
        }
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
