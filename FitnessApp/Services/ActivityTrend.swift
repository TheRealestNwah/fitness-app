import Foundation

/// One day of steps and active energy read from Apple Health.
struct ActivityDay: Equatable, Identifiable {
    var date: Date
    var steps: Int
    var activeKcal: Double

    var id: Date { date }
}

/// The daily step goal and the numbers behind the Activity card's trend screen.
enum ActivityTrend {
    /// Daily step goal in user defaults; 0 means no goal.
    static let stepGoalKey = "stepGoal"
    static let stepGoalStep = 500
    static let maxStepGoal = 50_000

    static var stepGoal: Int {
        UserDefaults.standard.integer(forKey: stepGoalKey)
    }

    static func clampedGoal(_ value: Int) -> Int {
        min(max(value, 0), maxStepGoal)
    }

    /// Share of the goal reached, 0...1; 0 when there's no goal.
    static func progress(steps: Int, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(Double(steps) / Double(goal), 0), 1)
    }

    struct Summary: Equatable {
        var averageSteps: Int
        var averageActiveKcal: Double
        /// Days that reached the goal, out of `days`; nil when there's no goal.
        var daysAtGoal: Int?
        var days: Int
        var bestDay: ActivityDay?
    }

    /// Averages over the days that have any data. Today counts, since it only ever adds to the average
    /// once there's something to count; days with no steps and no energy are left out (no watch worn, no Health data).
    static func summary(_ days: [ActivityDay], goal: Int) -> Summary {
        let recorded = days.filter { $0.steps > 0 || $0.activeKcal > 0 }
        guard !recorded.isEmpty else {
            return Summary(averageSteps: 0, averageActiveKcal: 0, daysAtGoal: goal > 0 ? 0 : nil, days: 0, bestDay: nil)
        }
        let steps = Double(recorded.reduce(0) { $0 + $1.steps }) / Double(recorded.count)
        let kcal = recorded.reduce(0) { $0 + $1.activeKcal } / Double(recorded.count)
        return Summary(averageSteps: Int(steps.rounded()),
                       averageActiveKcal: kcal,
                       daysAtGoal: goal > 0 ? recorded.filter { $0.steps >= goal }.count : nil,
                       days: recorded.count,
                       bestDay: recorded.max { $0.steps < $1.steps })
    }
}
