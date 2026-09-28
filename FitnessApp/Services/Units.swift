import Foundation

/// Converts stored metric values to whatever the user prefers to see.
struct Units {
    let system: UnitSystem
    /// Kilograms, pounds or stones; follows the unit system unless chosen separately.
    let weight: WeightUnit

    init(system: UnitSystem, weight: WeightUnit? = nil) {
        self.system = system
        self.weight = weight ?? (system == .metric ? .kg : .lb)
    }

    static let lbPerKg = 2.20462
    static let lbPerStone = 14.0
    static let inchPerCm = 0.393701
    static let flOzPerMl = 0.033814

    // MARK: Weight

    var weightUnit: String { weight.rawValue }

    /// Numbers for fields and charts: kilograms, pounds, or stones as a decimal.
    func weightValue(kg: Double) -> Double {
        switch weight {
        case .kg: return kg
        case .lb: return kg * Units.lbPerKg
        case .st: return kg * Units.lbPerKg / Units.lbPerStone
        }
    }

    func kg(fromDisplayWeight value: Double) -> Double {
        switch weight {
        case .kg: return value
        case .lb: return value / Units.lbPerKg
        case .st: return value * Units.lbPerStone / Units.lbPerKg
        }
    }

    /// Stones read as "12 st 4.5 lb"; a change under a stone reads in pounds ("-3.2 lb").
    func weightString(kg: Double, decimals: Int = 1, signed: Bool = false) -> String {
        if weight == .st {
            let pounds = kg * Units.lbPerKg
            let sign = pounds < 0 ? "-" : (signed ? "+" : "")
            let total = abs(pounds)
            if signed && total < Units.lbPerStone {
                return "\(sign)\(String(format: "%.\(decimals)f", total)) lb"
            }
            var stones = Int(total / Units.lbPerStone)
            var rest = (total - Double(stones) * Units.lbPerStone)
            if (rest * 10).rounded() / 10 >= Units.lbPerStone { stones += 1; rest = 0 }
            return "\(sign)\(stones) st \(String(format: "%.\(decimals)f", rest)) lb"
        }
        let value = weightValue(kg: kg)
        let formatted = String(format: "%\(signed ? "+" : "").\(decimals)f", value)
        return "\(formatted) \(weightUnit)"
    }

    // MARK: Length

    var lengthUnit: String { system == .metric ? "cm" : "in" }

    func lengthValue(cm: Double) -> Double {
        system == .metric ? cm : cm * Units.inchPerCm
    }

    func cm(fromDisplayLength value: Double) -> Double {
        system == .metric ? value : value / Units.inchPerCm
    }

    func lengthString(cm: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f %@", lengthValue(cm: cm), lengthUnit)
    }

    func heightString(cm: Double) -> String {
        if system == .metric {
            return String(format: "%.0f cm", cm)
        }
        let totalInches = cm * Units.inchPerCm
        let feet = Int(totalInches / 12)
        let inches = Int((totalInches - Double(feet) * 12).rounded())
        return "\(feet)′ \(inches)″"
    }

    static func cm(feet: Int, inches: Int) -> Double {
        Double(feet * 12 + inches) / Units.inchPerCm
    }

    // MARK: Volume

    var volumeUnit: String { system == .metric ? "ml" : "fl oz" }

    func volumeValue(ml: Double) -> Double {
        system == .metric ? ml : ml * Units.flOzPerMl
    }

    func volumeString(ml: Double) -> String {
        if system == .metric {
            return ml >= 1000 ? String(format: "%.1f L", ml / 1000) : String(format: "%.0f ml", ml)
        }
        return String(format: "%.0f fl oz", ml * Units.flOzPerMl)
    }

    /// A single "glass" the quick-add buttons use.
    var glassMl: Double { system == .metric ? 250 : 236.6 }
    var glassLabel: String { system == .metric ? "250 ml" : "8 fl oz" }
}

extension Double {
    /// Formats without trailing ".0" when the number is whole.
    var cleanString: String {
        self == rounded() ? String(Int(self)) : String(format: "%.1f", self)
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    var isToday: Bool { Calendar.current.isDateInToday(self) }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// "Today", "Yesterday", or a short weekday/date.
    var relativeDayLabel: String {
        if Calendar.current.isDateInToday(self) { return String(localized: "Today") }
        if Calendar.current.isDateInYesterday(self) { return String(localized: "Yesterday") }
        if Calendar.current.isDateInTomorrow(self) { return String(localized: "Tomorrow") }
        return formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg, lb, st

    var id: String { rawValue }
    var label: String {
        switch self {
        case .kg: return String(localized: "Kilograms")
        case .lb: return String(localized: "Pounds")
        case .st: return String(localized: "Stones and pounds")
        }
    }
}

/// Calories or kilojoules for display. A device preference, like appearance.
enum EnergyUnit: String, CaseIterable, Identifiable {
    case kcal, kJ

    static let storageKey = "energyUnit"
    static let kJPerKcal = 4.184

    var id: String { rawValue }
    var label: String { self == .kcal ? String(localized: "Calories (kcal)") : String(localized: "Kilojoules (kJ)") }

    static var current: EnergyUnit {
        EnergyUnit(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .kcal
    }

    func value(kcal: Double) -> Double { self == .kcal ? kcal : kcal * Self.kJPerKcal }

    func string(kcal: Double) -> String { "\(Int(value(kcal: kcal).rounded())) \(rawValue)" }
}

/// Formats energy in the user's chosen unit.
enum Energy {
    static var unit: String { EnergyUnit.current.rawValue }
    static func string(_ kcal: Double) -> String { EnergyUnit.current.string(kcal: kcal) }
    static func string(_ kcal: Int) -> String { string(Double(kcal)) }
    /// Just the number, for places that show the unit separately.
    static func number(_ kcal: Double) -> String { "\(Int(EnergyUnit.current.value(kcal: kcal).rounded()))" }
    static func number(_ kcal: Int) -> String { number(Double(kcal)) }
}
