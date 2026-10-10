import Foundation

/// The vitamins and minerals Stride tracks. Units are fixed per nutrient (see `unit`).
enum Micronutrient: String, CaseIterable, Codable, Identifiable {
    case calcium, iron, magnesium, zinc, vitaminD, vitaminB12, vitaminC, vitaminA, folate

    var id: String { rawValue }

    var name: String {
        switch self {
        case .calcium: return "Calcium"
        case .iron: return "Iron"
        case .magnesium: return "Magnesium"
        case .zinc: return "Zinc"
        case .vitaminD: return "Vitamin D"
        case .vitaminB12: return "Vitamin B12"
        case .vitaminC: return "Vitamin C"
        case .vitaminA: return "Vitamin A"
        case .folate: return "Folate"
        }
    }

    /// "mg" or "mcg".
    var unit: String {
        switch self {
        case .vitaminD, .vitaminB12, .vitaminA, .folate: return "mcg"
        default: return "mg"
        }
    }

    /// Grams per unit, to convert from and to Open Food Facts (grams) and Apple Health.
    var gramsPerUnit: Double { unit == "mg" ? 0.001 : 0.000_001 }

    /// Open Food Facts nutriment key (values are in grams).
    var openFoodFactsKey: String {
        switch self {
        case .calcium: return "calcium"
        case .iron: return "iron"
        case .magnesium: return "magnesium"
        case .zinc: return "zinc"
        case .vitaminD: return "vitamin-d"
        case .vitaminB12: return "vitamin-b12"
        case .vitaminC: return "vitamin-c"
        case .vitaminA: return "vitamin-a"
        case .folate: return "vitamin-b9"
        }
    }

    /// FoodData Central nutrient numbers, in preference order.
    var foodDataCentralIDs: [Int] {
        switch self {
        case .calcium: return [1087]
        case .iron: return [1089]
        case .magnesium: return [1090]
        case .zinc: return [1095]
        case .vitaminD: return [1114]
        case .vitaminB12: return [1178]
        case .vitaminC: return [1162]
        case .vitaminA: return [1106]
        case .folate: return [1190, 1177]
        }
    }

    /// Label words, lowercase, used by the nutrition label parser.
    var labelWords: [String] {
        switch self {
        case .calcium: return ["calcium"]
        case .iron: return ["iron"]
        case .magnesium: return ["magnesium"]
        case .zinc: return ["zinc"]
        case .vitaminD: return ["vitamin d"]
        case .vitaminB12: return ["vitamin b12", "vitamin b-12", "cobalamin"]
        case .vitaminC: return ["vitamin c", "ascorbic"]
        case .vitaminA: return ["vitamin a"]
        case .folate: return ["folate", "folic acid"]
        }
    }

    /// CSV column name.
    var csvColumn: String {
        switch self {
        case .calcium: return "calcium_mg"
        case .iron: return "iron_mg"
        case .magnesium: return "magnesium_mg"
        case .zinc: return "zinc_mg"
        case .vitaminD: return "vitamin_d_mcg"
        case .vitaminB12: return "vitamin_b12_mcg"
        case .vitaminC: return "vitamin_c_mg"
        case .vitaminA: return "vitamin_a_mcg"
        case .folate: return "folate_mcg"
        }
    }
}

/// Amounts of each micronutrient in a food or a day. Zero means "not recorded", as with the
/// other optional nutrients, so totals can say how many foods actually had data.
struct Micronutrients: Codable, Hashable {
    var calcium: Double = 0
    var iron: Double = 0
    var magnesium: Double = 0
    var zinc: Double = 0
    var vitaminD: Double = 0
    var vitaminB12: Double = 0
    var vitaminC: Double = 0
    var vitaminA: Double = 0
    var folate: Double = 0

    subscript(nutrient: Micronutrient) -> Double {
        get {
            switch nutrient {
            case .calcium: return calcium
            case .iron: return iron
            case .magnesium: return magnesium
            case .zinc: return zinc
            case .vitaminD: return vitaminD
            case .vitaminB12: return vitaminB12
            case .vitaminC: return vitaminC
            case .vitaminA: return vitaminA
            case .folate: return folate
            }
        }
        set {
            switch nutrient {
            case .calcium: calcium = newValue
            case .iron: iron = newValue
            case .magnesium: magnesium = newValue
            case .zinc: zinc = newValue
            case .vitaminD: vitaminD = newValue
            case .vitaminB12: vitaminB12 = newValue
            case .vitaminC: vitaminC = newValue
            case .vitaminA: vitaminA = newValue
            case .folate: folate = newValue
            }
        }
    }

    /// True when at least one nutrient was recorded.
    var hasData: Bool { Micronutrient.allCases.contains { self[$0] > 0 } }

    func scaled(by factor: Double) -> Micronutrients {
        var result = self
        for n in Micronutrient.allCases { result[n] = self[n] * factor }
        return result
    }

    static func + (lhs: Micronutrients, rhs: Micronutrients) -> Micronutrients {
        var result = lhs
        for n in Micronutrient.allCases { result[n] = lhs[n] + rhs[n] }
        return result
    }

    static func += (lhs: inout Micronutrients, rhs: Micronutrients) { lhs = lhs + rhs }
}

/// Recommended daily intakes (US RDA / AI for adults and teens) by age and sex.
enum ReferenceIntakes {
    static func amount(for nutrient: Micronutrient, sex: BiologicalSex, age: Int) -> Double {
        let male = sex == .male
        let older = age >= 51
        switch nutrient {
        case .calcium:
            if age < 19 { return 1300 }
            if male { return age >= 71 ? 1200 : 1000 }
            return older ? 1200 : 1000
        case .iron:
            if age < 19 { return male ? 11 : 15 }
            if male { return 8 }
            return older ? 8 : 18
        case .magnesium:
            if age < 19 { return male ? 410 : 360 }
            if age < 31 { return male ? 400 : 310 }
            return male ? 420 : 320
        case .zinc:
            if age < 19 { return male ? 11 : 9 }
            return male ? 11 : 8
        case .vitaminD:
            if age >= 71 { return 20 }
            return 15
        case .vitaminB12:
            return 2.4
        case .vitaminC:
            if age < 19 { return male ? 75 : 65 }
            return male ? 90 : 75
        case .vitaminA:
            return male ? 900 : 700
        case .folate:
            return 400
        }
    }

    static func targets(sex: BiologicalSex, age: Int) -> [Micronutrient: Double] {
        Dictionary(uniqueKeysWithValues: Micronutrient.allCases.map { ($0, amount(for: $0, sex: sex, age: age)) })
    }
}

/// Totals over a set of days, with how many foods had data so gaps are shown honestly.
struct MicronutrientSummary: Equatable {
    var totals = Micronutrients()
    /// Diary lines that recorded at least one micronutrient.
    var foodsWithData = 0
    var foodCount = 0
    var days = 1

    static func make(entries: [FoodLogEntry], days: Int = 1) -> MicronutrientSummary {
        var summary = MicronutrientSummary(days: max(days, 1))
        summary.foodCount = entries.count
        for entry in entries where entry.micros.hasData {
            summary.totals += entry.micros
            summary.foodsWithData += 1
        }
        return summary
    }

    /// Average per day over the period.
    func perDay(_ nutrient: Micronutrient) -> Double { totals[nutrient] / Double(days) }

    /// Fraction of the reference intake reached, per day, or nil for no recorded data.
    func progress(_ nutrient: Micronutrient, reference: Double) -> Double? {
        guard foodsWithData > 0, reference > 0 else { return nil }
        return perDay(nutrient) / reference
    }

    var coverageText: String {
        foodCount == 0 ? "No foods logged" : "Based on \(foodsWithData) of \(foodCount) foods"
    }
}

#if canImport(HealthKit)
import HealthKit

extension Micronutrient {
    /// The Apple Health type the nutrient is written as.
    var healthIdentifier: HKQuantityTypeIdentifier {
        switch self {
        case .calcium: return .dietaryCalcium
        case .iron: return .dietaryIron
        case .magnesium: return .dietaryMagnesium
        case .zinc: return .dietaryZinc
        case .vitaminD: return .dietaryVitaminD
        case .vitaminB12: return .dietaryVitaminB12
        case .vitaminC: return .dietaryVitaminC
        case .vitaminA: return .dietaryVitaminA
        case .folate: return .dietaryFolate
        }
    }
}
#endif
