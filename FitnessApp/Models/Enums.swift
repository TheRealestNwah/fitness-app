import Foundation

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case female
    case male

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly active"
        case .moderate: return "Moderately active"
        case .active: return "Very active"
        case .veryActive: return "Athlete"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return "Desk job, little or no exercise"
        case .light: return "Light exercise 1–3 days a week"
        case .moderate: return "Moderate exercise 3–5 days a week"
        case .active: return "Hard exercise 6–7 days a week"
        case .veryActive: return "Very hard exercise or a physical job"
        }
    }

    /// Standard TDEE multiplier applied to BMR.
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }
}

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }
    var label: String {
        switch self {
        case .metric: return "Metric (kg, cm)"
        case .imperial: return "Imperial (lb, ft/in)"
        }
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snacks"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        }
    }

    /// Share of the daily calorie budget typically given to this meal.
    var budgetShare: Double {
        switch self {
        case .breakfast: return 0.25
        case .lunch: return 0.35
        case .dinner: return 0.30
        case .snack: return 0.10
        }
    }

    /// The meal a user is most likely logging right now.
    static func current(at date: Date = .now) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 4..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default: return .snack
        }
    }
}

enum WeeklyGoalRate: Double, CaseIterable, Identifiable {
    case gentle = 0.25
    case steady = 0.5
    case brisk = 0.75
    case aggressive = 1.0

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .gentle: return "Gentle"
        case .steady: return "Steady"
        case .brisk: return "Brisk"
        case .aggressive: return "Aggressive"
        }
    }
}

enum VitalKind: String, CaseIterable, Identifiable {
    case bloodPressure
    case restingHeartRate
    case bodyFat
    case waist
    case hips
    case chest
    case sleep
    case bloodGlucose

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bloodPressure: return "Blood pressure"
        case .restingHeartRate: return "Resting heart rate"
        case .bodyFat: return "Body fat"
        case .waist: return "Waist"
        case .hips: return "Hips"
        case .chest: return "Chest"
        case .sleep: return "Sleep"
        case .bloodGlucose: return "Blood glucose"
        }
    }

    var systemImage: String {
        switch self {
        case .bloodPressure: return "waveform.path.ecg"
        case .restingHeartRate: return "heart.fill"
        case .bodyFat: return "percent"
        case .waist, .hips, .chest: return "ruler.fill"
        case .sleep: return "bed.double.fill"
        case .bloodGlucose: return "drop.fill"
        }
    }
}

enum BloodPressureCategory: String {
    case low = "Low"
    case normal = "Normal"
    case elevated = "Elevated"
    case stage1 = "High (stage 1)"
    case stage2 = "High (stage 2)"
    case crisis = "Hypertensive crisis"
}
