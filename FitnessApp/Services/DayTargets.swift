import Foundation

/// Whether a day is one the user trains on, which moves calories and carbs between day types.
enum DayType: String {
    case training, rest

    var label: String {
        switch self {
        case .training: return String(localized: "Training day")
        case .rest: return String(localized: "Rest day")
        }
    }

    var systemImage: String {
        switch self {
        case .training: return "figure.run"
        case .rest: return "bed.double.fill"
        }
    }
}

/// The user's training-day settings.
struct TrainingPlan: Equatable {
    var enabled = false
    /// `Calendar` weekday numbers (1 = Sunday … 7 = Saturday).
    var weekdays: Set<Int> = TrainingPlan.defaultWeekdays
    /// A workout logged or imported from Health turns the day into a training day.
    var fromWorkouts = false
    /// Extra calories on a training day; rest days give back the same total across the week.
    var bonusKcal = 250
    /// Percentage points of the macro split moved from fat to carbs on training days, and back on rest days.
    var carbShiftPercent = 10
    /// A one-day manual choice, forgotten the next day.
    var overrideDay: Date?
    var overrideIsTraining = false

    static let defaultWeekdays: Set<Int> = [2, 4, 6]
    static let bonusRange: ClosedRange<Int> = 0...600
    static let carbShiftRange: ClosedRange<Int> = 0...15
}

/// Per-day-type calorie and macro targets. The rest-day cut is sized so a full week of scheduled
/// training days averages out to the overall target, which leaves the goal-date forecast unchanged.
enum DayTargets {
    /// Used to size the rest-day cut when training days are only picked by workout, not by weekday.
    static let assumedTrainingDays = 3

    static func weekdayMask(_ weekdays: Set<Int>) -> Int {
        weekdays.reduce(0) { $0 | (1 << ($1 - 1)) }
    }

    static func weekdays(fromMask mask: Int) -> Set<Int> {
        Set((1...7).filter { mask & (1 << ($0 - 1)) != 0 })
    }

    /// Training days in a typical week, at least one and at most six.
    static func expectedTrainingDays(_ plan: TrainingPlan) -> Int {
        let count = plan.weekdays.isEmpty ? assumedTrainingDays : plan.weekdays.count
        return min(max(count, 1), 6)
    }

    /// Nil when training days are turned off.
    static func dayType(on date: Date, plan: TrainingPlan, hasWorkout: Bool,
                        calendar: Calendar = .current) -> DayType? {
        guard plan.enabled else { return nil }
        if let day = plan.overrideDay, calendar.isDate(day, inSameDayAs: date) {
            return plan.overrideIsTraining ? .training : .rest
        }
        if plan.fromWorkouts && hasWorkout { return .training }
        return plan.weekdays.contains(calendar.component(.weekday, from: date)) ? .training : .rest
    }

    /// Calories taken off each rest day so the week averages to the overall target.
    static func restCutKcal(_ plan: TrainingPlan) -> Int {
        let days = expectedTrainingDays(plan)
        return Int((Double(plan.bonusKcal * days) / Double(7 - days)).rounded())
    }

    /// Calories to add to (or take from) the overall target for this kind of day.
    static func calorieOffset(_ type: DayType?, plan: TrainingPlan) -> Int {
        switch type {
        case .training: return plan.bonusKcal
        case .rest: return -restCutKcal(plan)
        case nil: return 0
        }
    }

    /// The overall target moved for the day type, never below the safety floor.
    static func calorieTarget(base: Int, type: DayType?, plan: TrainingPlan, floor: Int) -> Int {
        guard type != nil else { return base }
        return max(base + calorieOffset(type, plan: plan), min(floor, base))
    }

    /// Protein, carbs and fat percentages with carbs shifted towards training days.
    static func split(protein: Double, carbs: Double, fat: Double, type: DayType?,
                      plan: TrainingPlan) -> (protein: Double, carbs: Double, fat: Double) {
        guard let type else { return (protein, carbs, fat) }
        let shift = Double(plan.carbShiftPercent) * (type == .training ? 1 : -1)
        // Never take more fat than there is.
        let moved = min(max(shift, -carbs + 5), max(fat - 5, 0))
        return (protein, carbs + moved, fat - moved)
    }
}
