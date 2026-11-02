import Foundation
import SwiftData

/// One day's nutrition: what was eaten, the day's targets, what's left, and the activity credit.
///
/// Every screen that shows a day's numbers gets them from here, so Today, the Food diary, the meal
/// plan, the widgets, Watch, Mac menu bar, Siri and reminders can't drift apart. Callers hand over
/// records as they have them (a view's `@Query` results, or a fetch); this type decides which ones
/// count, which weight to use and which adjustments apply, through `DayBudget`.
///
/// Summaries over many days (weekly review, monthly report, plateau check, partner share) use
/// `dailyTarget(profile:latestWeightKg:)` instead: weekly budgeting, training/rest days and the
/// day's activity credit are per-day adjustments that average out over a week by design.
struct DayNutrition {
    /// Calories and macros, eaten or left.
    struct Totals: Equatable {
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double

        static let zero = Totals(calories: 0, protein: 0, carbs: 0, fat: 0)
    }

    /// One diary line, reduced to what the day's numbers need.
    struct Food: Equatable {
        var date: Date
        var calories: Double
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
    }

    /// One logged workout, reduced to what the activity credit needs.
    struct Workout: Equatable {
        var date: Date
        var calories: Double
    }

    /// Start of the day these numbers are for.
    let day: Date
    /// The weight the targets were worked out from.
    let weightKg: Double
    let budget: DayBudget
    let eaten: Totals

    /// The day's full calorie budget, with weekly budgeting, day type and activity applied.
    var target: Int { budget.calories }
    var macros: MacroTargets { budget.macros }
    /// The target before day-type offsets and activity (today's share of the week when weekly budgeting is on).
    var base: Int { budget.base }
    /// Calories added back from activity; only ever non-zero for today.
    var activeCredit: Int { budget.activeCredit }
    var dayType: DayType? { budget.dayType }

    /// Negative when over.
    var remaining: Totals {
        Totals(calories: Double(target) - eaten.calories, protein: macros.protein - eaten.protein,
               carbs: macros.carbs - eaten.carbs, fat: macros.fat - eaten.fat)
    }

    // MARK: Plain targets

    /// The plain daily target: no weekly budgeting, day type or activity. For summaries over many days.
    static func dailyTarget(profile: UserProfile, latestWeightKg: Double?) -> Int {
        profile.calorieTarget(currentWeightKg: profile.currentWeightKg(latestWeighIn: latestWeightKg))
    }

    /// Macro targets that go with `dailyTarget`.
    static func dailyMacros(profile: UserProfile, latestWeightKg: Double?) -> MacroTargets {
        profile.macroTargets(currentWeightKg: profile.currentWeightKg(latestWeighIn: latestWeightKg))
    }

    // MARK: Building a day

    /// - Parameters:
    ///   - day: Any moment in the day wanted.
    ///   - food: Diary lines; may include other days. The day's own lines count as eaten, and earlier
    ///     days this week feed weekly budgeting when `day` is today.
    ///   - exercise: Logged workouts; may include other days. Only the day's own count.
    ///   - latestWeightKg: The most recent weigh-in, or nil to fall back to the starting weight.
    ///   - healthCredit: Earn-back from Apple Health active energy for today, already worked out.
    static func make(profile: UserProfile, day: Date, food: [Food], exercise: [Workout], latestWeightKg: Double?,
                     healthCredit: Int, earnBackPercent: Int, now: Date = .now,
                     calendar: Calendar = .current) -> DayNutrition {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? day
        let inDay = { (date: Date) in date >= start && date < end }

        var intakeByDay: [Date: Double] = [:]
        var eaten = Totals.zero
        for line in food {
            intakeByDay[calendar.startOfDay(for: line.date), default: 0] += line.calories
            guard inDay(line.date) else { continue }
            eaten.calories += line.calories
            eaten.protein += line.protein
            eaten.carbs += line.carbs
            eaten.fat += line.fat
        }
        let workouts = exercise.filter { inDay($0.date) }
        let weightKg = profile.currentWeightKg(latestWeighIn: latestWeightKg)
        let budget = DayBudget.make(profile: profile, currentKg: weightKg, date: day, today: now,
                                    intakeByDay: intakeByDay,
                                    exerciseKcal: workouts.reduce(0) { $0 + $1.calories },
                                    hasWorkout: !workouts.isEmpty, healthCredit: healthCredit,
                                    earnBackPercent: earnBackPercent, calendar: calendar)
        return DayNutrition(day: start, weightKg: weightKg, budget: budget, eaten: eaten)
    }

    /// The day from records a view already has, with today's Apple Health credit and the earn-back setting.
    @MainActor
    static func make(profile: UserProfile, day: Date, food: [FoodLogEntry], exercise: [ExerciseEntry],
                     latestWeightKg: Double?, now: Date = .now) -> DayNutrition {
        make(profile: profile, day: day,
             food: food.map { Food($0) }, exercise: exercise.map { Workout($0) },
             latestWeightKg: latestWeightKg,
             healthCredit: HealthKitManager.shared.activeEnergyCredit,
             earnBackPercent: ExerciseSettings.earnBackPercent, now: now)
    }

    /// The day, fetched from the store: for code that has no `@Query` of its own (widgets, Siri,
    /// reminders, screens whose day changes under them).
    @MainActor
    static func `for`(_ day: Date, in context: ModelContext, profile: UserProfile, now: Date = .now) -> DayNutrition {
        let records = Records.fetch(for: day, in: context)
        return make(profile: profile, day: day, food: records.food, exercise: records.exercise,
                    latestWeightKg: records.latestWeightKg, now: now)
    }

    /// What `for(_:in:profile:)` reads from the store.
    struct Records {
        var food: [FoodLogEntry]
        var exercise: [ExerciseEntry]
        var latestWeightKg: Double?

        /// From the start of the day's week (for weekly budgeting) to the end of the day.
        static func fetch(for day: Date, in context: ModelContext, calendar: Calendar = .current) -> Records {
            let start = calendar.startOfDay(for: day)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? day
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
            let food = (try? context.fetch(FetchDescriptor<FoodLogEntry>(
                predicate: #Predicate { $0.date >= weekStart && $0.date < end }))) ?? []
            let exercise = (try? context.fetch(FetchDescriptor<ExerciseEntry>(
                predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? []
            return Records(food: food, exercise: exercise, latestWeightKg: latestWeightKg(in: context))
        }

        static func latestWeightKg(in context: ModelContext) -> Double? {
            var latest = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            latest.fetchLimit = 1
            return (try? context.fetch(latest))?.first?.weightKg
        }
    }
}

extension DayNutrition.Food {
    init(_ entry: FoodLogEntry) {
        self.init(date: entry.date, calories: entry.calories, protein: entry.protein, carbs: entry.carbs, fat: entry.fat)
    }
}

extension DayNutrition.Workout {
    init(_ entry: ExerciseEntry) {
        self.init(date: entry.date, calories: entry.calories)
    }
}
