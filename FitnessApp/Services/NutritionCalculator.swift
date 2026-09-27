import Foundation

struct MacroTargets {
    var protein: Double
    var carbs: Double
    var fat: Double
}

/// Pure functions for every number the app derives. Kept free of UI and SwiftData so it can be unit tested.
enum NutritionCalculator {
    /// Approximate energy stored in one kilogram of body fat.
    static let kcalPerKgFat: Double = 7700

    static func age(birthDate: Date, on date: Date = .now) -> Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: date).year ?? 0
    }

    /// Mifflin-St Jeor resting energy expenditure.
    static func bmr(sex: BiologicalSex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activity.multiplier
    }

    /// Minimum daily intake we will recommend without medical supervision.
    static func calorieFloor(for sex: BiologicalSex) -> Int {
        sex == .male ? 1500 : 1200
    }

    /// Daily calorie target for a given weekly loss, never dropping below a safe floor.
    static func dailyCalorieTarget(tdee: Double, weeklyLossKg: Double, sex: BiologicalSex) -> Int {
        let dailyDeficit = weeklyLossKg * kcalPerKgFat / 7
        let raw = Int((tdee - dailyDeficit).rounded())
        return max(raw, calorieFloor(for: sex))
    }

    static func bmi(weightKg: Double, heightCm: Double) -> Double {
        guard heightCm > 0 else { return 0 }
        let meters = heightCm / 100
        return weightKg / (meters * meters)
    }

    static func bmiCategory(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Healthy"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }

    static func macroGrams(calories: Int, proteinPercent: Double, carbsPercent: Double, fatPercent: Double) -> MacroTargets {
        let total = max(proteinPercent + carbsPercent + fatPercent, 1)
        let kcal = Double(calories)
        return MacroTargets(protein: kcal * (proteinPercent / total) / 4,
                            carbs: kcal * (carbsPercent / total) / 4,
                            fat: kcal * (fatPercent / total) / 9)
    }

    /// ~35 ml per kg of body weight, rounded to the nearest 250 ml.
    static func waterGoalMl(weightKg: Double) -> Double {
        let raw = weightKg * 35
        return (raw / 250).rounded() * 250
    }

    /// When the goal weight will be reached if the planned weekly loss holds.
    static func projectedGoalDate(currentKg: Double, goalKg: Double, weeklyLossKg: Double, from date: Date = .now) -> Date? {
        let remaining = currentKg - goalKg
        guard remaining > 0, weeklyLossKg > 0 else { return nil }
        let weeks = remaining / weeklyLossKg
        return Calendar.current.date(byAdding: .day, value: Int((weeks * 7).rounded(.up)), to: date)
    }

    /// Trailing moving average over the previous `window` points (inclusive).
    static func movingAverage(_ values: [Double], window: Int) -> [Double] {
        guard window > 1 else { return values }
        var result: [Double] = []
        result.reserveCapacity(values.count)
        for i in values.indices {
            let start = max(0, i - window + 1)
            let slice = values[start...i]
            result.append(slice.reduce(0, +) / Double(slice.count))
        }
        return result
    }

    /// Least-squares slope of weight against time, in kg per week. Returns nil with fewer than two points.
    static func weeklyRate(points: [(date: Date, weightKg: Double)]) -> Double? {
        guard points.count >= 2 else { return nil }
        let origin = points[0].date
        let xs = points.map { $0.date.timeIntervalSince(origin) / 86_400 }
        let ys = points.map { $0.weightKg }
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var num = 0.0
        var den = 0.0
        for i in xs.indices {
            num += (xs[i] - meanX) * (ys[i] - meanY)
            den += (xs[i] - meanX) * (xs[i] - meanX)
        }
        guard den > 0 else { return nil }
        return num / den * 7
    }

    static func bloodPressureCategory(systolic: Int, diastolic: Int) -> BloodPressureCategory {
        if systolic > 180 || diastolic > 120 { return .crisis }
        if systolic >= 140 || diastolic >= 90 { return .stage2 }
        if systolic >= 130 || diastolic >= 80 { return .stage1 }
        if systolic >= 120 { return .elevated }
        if systolic < 90 || diastolic < 60 { return .low }
        return .normal
    }

    /// Number of consecutive days, ending today, that contain at least one log.
    static func streak(logDates: [Date], today: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(logDates.map { calendar.startOfDay(for: $0) })
        var streak = 0
        var cursor = calendar.startOfDay(for: today)
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
