import Foundation

/// What the last few weeks of diary and scale data say your maintenance calories really are.
struct MaintenanceEstimate: Equatable {
    enum Confidence: String { case low, medium, high }

    var maintenanceKcal: Int
    var meanIntakeKcal: Double
    var weeklyWeightChangeKg: Double
    var daysLogged: Int
    var weighIns: Int
    var windowDays: Int
    var confidence: Confidence

    /// Daily target that would produce the planned weekly loss, floored for safety.
    func suggestedTarget(weeklyLossKg: Double, sex: BiologicalSex) -> Int {
        let deficit = weeklyLossKg * NutritionCalculator.kcalPerKgFat / 7
        return max(Int((Double(maintenanceKcal) - deficit).rounded()), NutritionCalculator.calorieFloor(for: sex))
    }
}

enum AdaptiveTargetCalculator {
    static let windowDays = 28
    static let minimumDaysLogged = 14
    static let minimumWeighIns = 4
    static let minimumWeighInSpanDays = 14

    /// Energy balance over the window: maintenance = mean intake − (daily weight change × kcal per kg).
    /// Returns nil until there is enough data for the answer to mean something.
    static func estimate(foodLogs: [WeeklyReviewCalculator.FoodDay],
                         weights: [WeeklyReviewCalculator.WeightDay],
                         today: Date = .now,
                         calendar: Calendar = .current) -> MaintenanceEstimate? {
        let windowEnd = calendar.startOfDay(for: today)
        guard let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: windowEnd) else { return nil }

        var perDay: [Date: Double] = [:]
        for log in foodLogs where log.date >= windowStart && log.date < windowEnd {
            perDay[calendar.startOfDay(for: log.date), default: 0] += log.calories
        }
        let daysLogged = perDay.count
        guard daysLogged >= minimumDaysLogged else { return nil }
        let meanIntake = perDay.values.reduce(0, +) / Double(daysLogged)

        let points = weights
            .filter { $0.date >= windowStart && $0.date < windowEnd }
            .sorted { $0.date < $1.date }
            .map { (date: $0.date, weightKg: $0.weightKg) }
        guard points.count >= minimumWeighIns,
              let first = points.first?.date, let last = points.last?.date,
              last.timeIntervalSince(first) >= Double(minimumWeighInSpanDays - 1) * 86_400,
              let weeklyRate = NutritionCalculator.weeklyRate(points: points) else { return nil }

        let dailyChangeKg = weeklyRate / 7
        let maintenance = meanIntake - dailyChangeKg * NutritionCalculator.kcalPerKgFat

        let confidence: MaintenanceEstimate.Confidence
        if daysLogged >= 24 && points.count >= 12 {
            confidence = .high
        } else if daysLogged >= 18 && points.count >= 7 {
            confidence = .medium
        } else {
            confidence = .low
        }

        return MaintenanceEstimate(maintenanceKcal: Int(maintenance.rounded()),
                                   meanIntakeKcal: meanIntake,
                                   weeklyWeightChangeKg: weeklyRate,
                                   daysLogged: daysLogged,
                                   weighIns: points.count,
                                   windowDays: windowDays,
                                   confidence: confidence)
    }
}
