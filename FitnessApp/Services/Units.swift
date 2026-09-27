import Foundation

/// Converts stored metric values to whatever the user prefers to see.
struct Units {
    let system: UnitSystem

    static let lbPerKg = 2.20462
    static let inchPerCm = 0.393701
    static let flOzPerMl = 0.033814

    // MARK: Weight

    var weightUnit: String { system == .metric ? "kg" : "lb" }

    func weightValue(kg: Double) -> Double {
        system == .metric ? kg : kg * Units.lbPerKg
    }

    func kg(fromDisplayWeight value: Double) -> Double {
        system == .metric ? value : value / Units.lbPerKg
    }

    func weightString(kg: Double, decimals: Int = 1, signed: Bool = false) -> String {
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
        if Calendar.current.isDateInToday(self) { return "Today" }
        if Calendar.current.isDateInYesterday(self) { return "Yesterday" }
        if Calendar.current.isDateInTomorrow(self) { return "Tomorrow" }
        return formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
