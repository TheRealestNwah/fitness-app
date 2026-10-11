import Foundation

/// A day's calorie and macro targets, worked out one way so Today and the Food diary always agree.
struct DayBudget {
    /// The daily target after weekly budgeting, before day-type offsets and activity.
    var base: Int
    /// Calories added back from activity (today only).
    var activeCredit: Int
    /// Training or rest day, when the person has separate targets for them.
    var dayType: DayType?
    /// The day's full calorie budget: base, day-type offset (never below the safety floor) and activity.
    var calories: Int
    var macros: MacroTargets

    /// - Parameters:
    ///   - intakeByDay: Calories eaten per day (keyed by start of day); used for weekly budgeting on today.
    ///   - exerciseKcal: Calories from the day's logged exercise.
    ///   - healthCredit: Earn-back from Apple Health active energy, already worked out.
    static func make(profile: UserProfile, currentKg: Double, date: Date, today: Date = .now,
                     intakeByDay: [Date: Double], exerciseKcal: Double, hasWorkout: Bool,
                     healthCredit: Int, earnBackPercent: Int) -> DayBudget {
        let isToday = Calendar.current.isDate(date, inSameDayAs: today)
        let daily = profile.calorieTarget(currentWeightKg: currentKg)
        let floor = NutritionCalculator.calorieFloor(for: profile.sex)
        var base = daily
        if isToday, profile.weeklyBudgetEnabled, !profile.isOnDietBreak, !profile.isMaintaining,
           profile.customCalorieTarget == nil {
            base = BudgetCalculator.weeklyAdjustedTarget(dailyTarget: daily, intakeByDay: intakeByDay,
                                                         floor: floor, today: today)
        }
        let credit = isToday
            ? ExerciseCatalog.combinedCredit(health: healthCredit,
                                             exercise: ExerciseCatalog.earnBack(exerciseKcal: exerciseKcal, percent: earnBackPercent))
            : 0
        let type = profile.dayType(on: date, hasWorkout: hasWorkout)
        let calories = max(base + profile.dayOffset(type), min(floor, base)) + credit
        return DayBudget(base: base, activeCredit: credit, dayType: type, calories: calories,
                         macros: profile.macroTargets(currentWeightKg: currentKg, dayType: type, baseCalories: base))
    }
}
