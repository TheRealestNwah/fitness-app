import Foundation

/// How blood glucose is shown and entered. Readings are always stored in mg/dL.
enum GlucoseUnit: String, CaseIterable, Identifiable {
    case mgdL, mmolL

    static let storageKey = "glucoseUnit"
    /// mg/dL in one mmol/L of glucose.
    static let mgPerMmol = 18.0
    /// Places that report glucose in mmol/L; most others, including the US, use mg/dL.
    static let mmolRegions: Set<String> = ["GB", "IE", "CA", "AU", "NZ", "ZA", "CN", "HK", "SG", "MY",
                                           "NL", "SE", "NO", "DK", "FI", "IS", "CZ", "SK", "RU", "UA"]

    var id: String { rawValue }

    var label: String { self == .mgdL ? "mg/dL" : "mmol/L" }

    /// The saved choice, or the usual unit for the person's region.
    static var current: GlucoseUnit {
        UserDefaults.standard.string(forKey: storageKey).flatMap(GlucoseUnit.init) ?? regionDefault()
    }

    static func regionDefault(_ region: String? = Locale.current.region?.identifier) -> GlucoseUnit {
        guard let region, mmolRegions.contains(region) else { return .mgdL }
        return .mmolL
    }

    func value(mgdL: Double) -> Double {
        self == .mgdL ? mgdL : mgdL / Self.mgPerMmol
    }

    func mgdL(from value: Double) -> Double {
        self == .mgdL ? value : value * Self.mgPerMmol
    }

    /// "95" or "5.3": whole numbers for mg/dL, one decimal for mmol/L.
    func number(mgdL: Double) -> String {
        self == .mgdL ? String(Int(mgdL.rounded())) : String(format: "%.1f", value(mgdL: mgdL))
    }

    func string(mgdL: Double) -> String { "\(number(mgdL: mgdL)) \(label)" }
}
