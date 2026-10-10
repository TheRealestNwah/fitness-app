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
    /// Separate calorie and carb targets for training and rest days (`DayTargets`).
    var trainingDaysEnabled: Bool = false
    /// Weekdays that count as training days, one bit per `Calendar` weekday (bit 0 = Sunday).
    var trainingWeekdayMask: Int = 42
    var trainingFromWorkouts: Bool = false
    var trainingBonusKcal: Int = 250
    var trainingCarbShift: Int = 10
    var dayTypeOverrideDay: Date?
    var dayTypeOverrideIsTraining: Bool = false
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
    /// Goals for the extra nutrients, shown when turned on in Settings.
    var saturatedFatLimitG: Double?
    var potassiumTargetMg: Double?
    var cholesterolLimitMg: Double?
    var startDate: Date = Date()
    var weighInReminderEnabled: Bool = false
    var weighInReminderHour: Int = 7
    var waterReminderEnabled: Bool = false
    var mealReminderEnabled: Bool = false
    /// Evening check-in when dinner isn't logged; nil when off.
    var dayCloseReminderHour: Int?
    /// Afternoon nudge when protein is well short of the target.
    var proteinReminderEnabled: Bool = false
    /// Hold weigh-in, meal, check-in and protein reminders during a diet break.
    var pauseRemindersOnDietBreak: Bool = false
    /// Weight-loss medication tracking (GLP-1), off by default.
    var medicationEnabled: Bool = false
    /// A `MedicationPlanner.medications` name, or empty.
    var medicationName: String = ""
    var medicationDoseMg: Double = 0
    /// Days between doses, for a medication not in the built-in list.
    var medicationIntervalDays: Int = 7
    var medicationStartDate: Date?
    var medicationReminderEnabled: Bool = false
    var medicationReminderHour: Int = 9

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

    var trainingPlan: TrainingPlan {
        get {
            TrainingPlan(enabled: trainingDaysEnabled, weekdays: DayTargets.weekdays(fromMask: trainingWeekdayMask),
                         fromWorkouts: trainingFromWorkouts, bonusKcal: trainingBonusKcal,
                         carbShiftPercent: trainingCarbShift, overrideDay: dayTypeOverrideDay,
                         overrideIsTraining: dayTypeOverrideIsTraining)
        }
        set {
            trainingDaysEnabled = newValue.enabled
            trainingWeekdayMask = DayTargets.weekdayMask(newValue.weekdays)
            trainingFromWorkouts = newValue.fromWorkouts
            trainingBonusKcal = newValue.bonusKcal
            trainingCarbShift = newValue.carbShiftPercent
            dayTypeOverrideDay = newValue.overrideDay
            dayTypeOverrideIsTraining = newValue.overrideIsTraining
        }
    }

    /// What kind of day this is, or nil when training days are off or the target is held flat
    /// (a diet break).
    func dayType(on date: Date = .now, hasWorkout: Bool) -> DayType? {
        guard !isOnDietBreak else { return nil }
        return DayTargets.dayType(on: date, plan: trainingPlan, hasWorkout: hasWorkout)
    }

    /// Calories to add to the day's budget for its type.
    func dayOffset(_ type: DayType?) -> Int { DayTargets.calorieOffset(type, plan: trainingPlan) }

    /// Macro targets for a day type: the day's calories and the carb-shifted split.
    func macroTargets(currentWeightKg: Double, dayType type: DayType?, baseCalories: Int? = nil) -> MacroTargets {
        let base = baseCalories ?? calorieTarget(currentWeightKg: currentWeightKg)
        let calories = DayTargets.calorieTarget(base: base, type: type, plan: trainingPlan,
                                                floor: NutritionCalculator.calorieFloor(for: sex))
        let split = DayTargets.split(protein: proteinPercent, carbs: carbsPercent, fat: fatPercent,
                                     type: type, plan: trainingPlan)
        return NutritionCalculator.macroGrams(calories: calories, proteinPercent: split.protein,
                                              carbsPercent: split.carbs, fatPercent: split.fat)
    }
}
