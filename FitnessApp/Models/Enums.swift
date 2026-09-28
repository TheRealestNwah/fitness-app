import Foundation
import SwiftUI

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case female
    case male

    var id: String { rawValue }
    var label: String { self == .female ? String(localized: "Female") : String(localized: "Male") }
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
        case .sedentary: return String(localized: "Sedentary")
        case .light: return String(localized: "Lightly active")
        case .moderate: return String(localized: "Moderately active")
        case .active: return String(localized: "Very active")
        case .veryActive: return String(localized: "Athlete")
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return String(localized: "Desk job, little or no exercise")
        case .light: return String(localized: "Light exercise 1–3 days a week")
        case .moderate: return String(localized: "Moderate exercise 3–5 days a week")
        case .active: return String(localized: "Hard exercise 6–7 days a week")
        case .veryActive: return String(localized: "Very hard exercise or a physical job")
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
        case .metric: return String(localized: "Metric (kg, cm)")
        case .imperial: return String(localized: "Imperial (lb, ft/in)")
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
        case .breakfast: return String(localized: "Breakfast")
        case .lunch: return String(localized: "Lunch")
        case .dinner: return String(localized: "Dinner")
        case .snack: return String(localized: "Snacks")
        }
    }

    /// The meal's name inside a sentence ("Log breakfast"). Languages that capitalise nouns keep the capital.
    var inSentence: String {
        switch self {
        case .breakfast: String(localized: "breakfast", comment: "Meal name inside a sentence")
        case .lunch: String(localized: "lunch", comment: "Meal name inside a sentence")
        case .dinner: String(localized: "dinner", comment: "Meal name inside a sentence")
        case .snack: String(localized: "snacks", comment: "Meal name inside a sentence")
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

    /// Hour of day used when logging to a day other than today.
    var typicalHour: Int {
        switch self {
        case .breakfast: return 8
        case .lunch: return 13
        case .dinner: return 19
        case .snack: return 16
        }
    }

    /// Timestamp for a new diary entry: now when logging today, otherwise a sensible hour on that day.
    func logDate(on day: Date) -> Date {
        if Calendar.current.isDateInToday(day) { return .now }
        return Calendar.current.date(bySettingHour: typicalHour, minute: 0, second: 0, of: day) ?? day
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
        case .gentle: return String(localized: "Gentle")
        case .steady: return String(localized: "Steady")
        case .brisk: return String(localized: "Brisk")
        case .aggressive: return String(localized: "Aggressive")
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
        case .bloodPressure: return String(localized: "Blood pressure")
        case .restingHeartRate: return String(localized: "Resting heart rate")
        case .bodyFat: return String(localized: "Body fat")
        case .waist: return String(localized: "Waist")
        case .hips: return String(localized: "Hips")
        case .chest: return String(localized: "Chest")
        case .sleep: return String(localized: "Sleep")
        case .bloodGlucose: return String(localized: "Blood glucose")
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

    var label: String {
        switch self {
        case .low: String(localized: "Low")
        case .normal: String(localized: "Normal")
        case .elevated: String(localized: "Elevated")
        case .stage1: String(localized: "High (stage 1)")
        case .stage2: String(localized: "High (stage 2)")
        case .crisis: String(localized: "Hypertensive crisis")
        }
    }
}

/// User-selectable colour scheme, stored in UserDefaults under "appearance".
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return String(localized: "Match system")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
