import Foundation

/// Where someone is on the way to their goal weight: lost, remaining, rate, forecast, milestones and plateau.
///
/// Today and the Weight screen both get these numbers from here, so they can't drift apart (they used
/// to work out the plateau with different targets). Callers hand over weigh-ins and diary lines as they
/// have them; this type decides which weigh-in is current, which days are left out for water retention
/// and which target the plateau check compares against. The maths stays in `ProgressCalculator`,
/// `NutritionCalculator`, `TrendReadiness` and `AdaptiveTargetCalculator`.
///
/// Building one is cheap; each result is worked out when it's read, so read it once per use.
struct WeightProgress {
    typealias WeightDay = WeeklyReviewCalculator.WeightDay
    typealias FoodDay = WeeklyReviewCalculator.FoodDay

    /// The next milestone and how far the 7-day trend still has to fall to reach it.
    struct NextMilestone: Equatable {
        var percent: Int
        var remainingKg: Double
    }

    let startKg: Double
    let goalKg: Double
    /// The latest weigh-in, or the starting weight before there is one.
    let currentKg: Double
    /// Every weigh-in, in any order.
    let weighIns: [WeightDay]
    /// Weigh-ins without likely water-retention days, for the trend-based checks (forecast, plateau).
    let trendWeighIns: [WeightDay]

    private let food: [FoodDay]
    private let plannedWeeklyLossKg: Double
    private let sex: BiologicalSex
    private let isMaintaining: Bool
    private let dietBreakStart: Date?
    private let dietBreakEnd: Date?
    /// The plain daily target (`DayNutrition.dailyTarget`), which the plateau check compares with maintenance.
    let dailyTarget: Int
    private let now: Date
    private let calendar: Calendar

    /// - Parameters:
    ///   - weighIns: Every weigh-in, in any order. The latest is the current weight.
    ///   - food: Diary lines covering at least the last four weeks, for the measured maintenance in the plateau check.
    ///   - retentionDays: Days likely to show water retention (start of day), left out of the forecast and plateau.
    init(profile: UserProfile, weighIns: [WeightDay], food: [FoodDay], retentionDays: Set<Date>,
         now: Date = .now, calendar: Calendar = .current) {
        let latest = weighIns.max { $0.date < $1.date }?.weightKg
        startKg = profile.startWeightKg
        goalKg = profile.goalWeightKg
        currentKg = profile.currentWeightKg(latestWeighIn: latest)
        self.weighIns = weighIns
        trendWeighIns = CycleCalculator.excludingRetention(weighIns, days: retentionDays, calendar: calendar)
        self.food = food
        plannedWeeklyLossKg = profile.weeklyLossKg
        sex = profile.sex
        isMaintaining = profile.isMaintaining
        dietBreakStart = profile.dietBreakStart
        dietBreakEnd = profile.dietBreakEnd
        dailyTarget = DayNutrition.dailyTarget(profile: profile, latestWeightKg: latest)
        self.now = now
        self.calendar = calendar
    }

    // MARK: Lost and remaining

    /// Change since the starting weight; positive means lost, negative means gained.
    var lostKg: Double { startKg - currentKg }

    /// Still to lose to reach the goal; zero once it's reached.
    var remainingKg: Double { max(currentKg - goalKg, 0) }

    var goalReached: Bool { remainingKg == 0 }

    /// 0…1, how much of the way from the starting weight to the goal has been covered.
    var goalFraction: Double {
        let total = max(startKg - goalKg, 0.001)
        return min(max(lostKg / total, 0), 1)
    }

    /// The 7-day trend today, or nil without a weigh-in in the last week.
    var trendKg: Double? { ProgressCalculator.trend(on: now, weights: weighIns, calendar: calendar) }

    // MARK: Rate and forecast

    /// How close the weigh-ins are to supporting a weekly rate.
    var rateReadiness: TrendProgress { TrendReadiness.rate(weights: weighIns, today: now, calendar: calendar) }

    /// Weight change per week over the last four weeks of weigh-ins, once there are enough of them.
    /// Negative means losing. (`TrendForecast.weeklyLossKg` is the other way round: positive means losing.)
    var weeklyChangeKg: Double? {
        guard rateReadiness.isReady else { return nil }
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let cutoff = calendar.date(byAdding: .day, value: -TrendReadiness.rateWindowDays, to: now) ?? now
        let recent = weighIns.filter { $0.date >= cutoff && $0.date < end }
            .sorted { $0.date < $1.date }
            .map { (date: $0.date, weightKg: $0.weightKg) }
        return NutritionCalculator.weeklyRate(points: recent)
    }

    /// How close the weigh-ins are to supporting a pace forecast.
    var forecastReadiness: TrendProgress {
        TrendReadiness.forecast(weights: trendWeighIns, today: now, calendar: calendar)
    }

    /// When the trend reaches the goal at the actual pace; nil without enough data or when not losing.
    var forecast: TrendForecast? {
        ProgressCalculator.trendForecast(weights: trendWeighIns, goalKg: goalKg, today: now, calendar: calendar)
    }

    /// When the goal would be reached at the planned pace, moved later by a diet break still ahead.
    var plannedGoalDate: Date? {
        BudgetCalculator.goalDate(
            NutritionCalculator.projectedGoalDate(currentKg: currentKg, goalKg: goalKg,
                                                  weeklyLossKg: plannedWeeklyLossKg, from: now),
            breakStart: dietBreakStart, breakEnd: dietBreakEnd, today: now, calendar: calendar)
    }

    // MARK: Milestones

    /// Every milestone reached so far, oldest first.
    var milestones: [Milestone] {
        ProgressCalculator.milestones(startKg: startKg, weights: weighIns, calendar: calendar)
    }

    var nextMilestone: NextMilestone? {
        ProgressCalculator.nextMilestone(startKg: startKg, weights: weighIns, today: now, calendar: calendar)
            .map { NextMilestone(percent: $0.percent, remainingKg: $0.remainingKg) }
    }

    /// A milestone reached in the last week, for a celebration card.
    var recentMilestone: Milestone? {
        ProgressCalculator.recentMilestone(startKg: startKg, weights: weighIns, today: now, calendar: calendar)
    }

    // MARK: Plateau

    /// A stall in the trend while there's still weight to lose. Never shown in maintenance mode,
    /// where holding steady is the point.
    var plateau: Plateau? {
        guard !isMaintaining else { return nil }
        let estimate = AdaptiveTargetCalculator.estimate(foodLogs: food, weights: weighIns, today: now, calendar: calendar)
        return ProgressCalculator.plateau(weights: trendWeighIns, goalKg: goalKg, currentTarget: dailyTarget,
                                          maintenance: estimate, weeklyLossKg: plannedWeeklyLossKg, sex: sex,
                                          today: now, calendar: calendar)
    }
}

extension WeightProgress {
    /// From the records a view already has, with the retention days from Apple Health cycle data.
    @MainActor
    init(profile: UserProfile, weighIns: [WeightEntry], food: [FoodLogEntry], now: Date = .now) {
        self.init(profile: profile,
                  weighIns: weighIns.map { WeightDay(date: $0.date, weightKg: $0.weightKg) },
                  food: food.map { FoodDay(date: $0.date, calories: $0.calories) },
                  retentionDays: HealthKitManager.shared.retentionDays, now: now)
    }
}
