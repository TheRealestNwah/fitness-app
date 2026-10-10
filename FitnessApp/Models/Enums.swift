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

/// One of the user's meal slots. The four defaults (`breakfast`, `lunch`, `dinner`, `snack`) keep their
/// ids; slots the user adds get their own. Names, icons, order and times come from `MealSlots`.
struct MealType: RawRepresentable, Codable, Hashable, Identifiable {
    let rawValue: String

    static let breakfast = MealType(id: "breakfast")
    static let lunch = MealType(id: "lunch")
    static let dinner = MealType(id: "dinner")
    static let snack = MealType(id: "snack")

    init(id: String) { rawValue = id }

    /// Nil when the user has no slot with this id (it was removed, or the data came from elsewhere).
    init?(rawValue: String) {
        guard MealSlots.shared.slots.contains(where: { $0.id == rawValue }) else { return nil }
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var id: String { rawValue }

    /// The user's meals, in the order they chose.
    static var allCases: [MealType] { MealSlots.shared.slots.map { MealType(id: $0.id) } }

    private var slot: MealSlot {
        MealSlots.shared.slots.first { $0.id == rawValue }
            ?? MealSlots.defaults.first { $0.id == rawValue }
            ?? MealSlots.defaults[3]
    }

    var label: String { slot.name }

    /// The meal's name inside a sentence ("Log breakfast").
    var inSentence: String { slot.name.lowercased() }

    var systemImage: String { slot.icon }

    /// Share of the daily calorie budget typically given to this meal.
    var budgetShare: Double {
        let slots = MealSlots.shared.slots
        let total = slots.reduce(0) { $0 + $1.share }
        guard total > 0 else { return 1 / Double(max(slots.count, 1)) }
        return slot.share / total
    }

    /// Hour of day used when logging to a day other than today.
    var typicalHour: Int { slot.hour }

    /// Whether the user wants a reminder to log this meal.
    var reminds: Bool { slot.reminds }

    /// Position in the user's list, for sorting.
    var order: Int { MealSlots.shared.slots.firstIndex { $0.id == rawValue } ?? Int.max }

    /// Timestamp for a new diary entry: now when logging today, otherwise a sensible hour on that day.
    func logDate(on day: Date) -> Date {
        if Calendar.current.isDateInToday(day) { return .now }
        return Calendar.current.date(bySettingHour: typicalHour, minute: 0, second: 0, of: day) ?? day
    }

    /// The meal a user is most likely logging right now.
    static func current(at date: Date = .now) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        let slots = MealSlots.shared.slots
        if slots == MealSlots.defaults {
            switch hour {
            case 4..<11: return .breakfast
            case 11..<15: return .lunch
            case 17..<22: return .dinner
            default: return .snack
            }
        }
        // The latest meal whose time has come; before the first one, the last meal of the day.
        let sorted = slots.sorted { $0.hour < $1.hour }
        let slot = sorted.last { $0.hour <= hour } ?? sorted.last ?? MealSlots.defaults[3]
        return MealType(id: slot.id)
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
