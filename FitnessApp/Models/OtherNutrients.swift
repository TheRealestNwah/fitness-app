import Foundation

/// Everything a food or entry records past calories and the three macros: fibre, sugar, sodium,
/// saturated fat, potassium, cholesterol, alcohol, caffeine, and vitamins and minerals.
/// Grouped so every way of building a diary entry carries all of them, not a hand-picked few.
struct OtherNutrients: Codable, Hashable {
    var fiber: Double = 0
    var sugar: Double = 0
    /// Milligrams.
    var sodium: Double = 0
    var saturatedFat: Double = 0
    /// Milligrams.
    var potassium: Double = 0
    /// Milligrams.
    var cholesterol: Double = 0
    /// Grams of pure alcohol (ethanol).
    var alcohol: Double = 0
    /// Milligrams.
    var caffeine: Double = 0
    var micros = Micronutrients()

    private enum CodingKeys: String, CodingKey {
        case fiber, sugar, sodium, saturatedFat, potassium, cholesterol, alcohol, caffeine, micros
    }

    func scaled(by factor: Double) -> OtherNutrients {
        OtherNutrients(fiber: fiber * factor, sugar: sugar * factor, sodium: sodium * factor,
                       saturatedFat: saturatedFat * factor, potassium: potassium * factor,
                       cholesterol: cholesterol * factor, alcohol: alcohol * factor, caffeine: caffeine * factor,
                       micros: micros.scaled(by: factor))
    }

    static func + (lhs: OtherNutrients, rhs: OtherNutrients) -> OtherNutrients {
        OtherNutrients(fiber: lhs.fiber + rhs.fiber, sugar: lhs.sugar + rhs.sugar, sodium: lhs.sodium + rhs.sodium,
                       saturatedFat: lhs.saturatedFat + rhs.saturatedFat, potassium: lhs.potassium + rhs.potassium,
                       cholesterol: lhs.cholesterol + rhs.cholesterol, alcohol: lhs.alcohol + rhs.alcohol,
                       caffeine: lhs.caffeine + rhs.caffeine, micros: lhs.micros + rhs.micros)
    }
}

extension OtherNutrients {
    // Every key is optional, so nutrients added later still decode from older recipes and backups.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fiber = try c.decodeIfPresent(Double.self, forKey: .fiber) ?? 0
        sugar = try c.decodeIfPresent(Double.self, forKey: .sugar) ?? 0
        sodium = try c.decodeIfPresent(Double.self, forKey: .sodium) ?? 0
        saturatedFat = try c.decodeIfPresent(Double.self, forKey: .saturatedFat) ?? 0
        potassium = try c.decodeIfPresent(Double.self, forKey: .potassium) ?? 0
        cholesterol = try c.decodeIfPresent(Double.self, forKey: .cholesterol) ?? 0
        alcohol = try c.decodeIfPresent(Double.self, forKey: .alcohol) ?? 0
        caffeine = try c.decodeIfPresent(Double.self, forKey: .caffeine) ?? 0
        micros = try c.decodeIfPresent(Micronutrients.self, forKey: .micros) ?? Micronutrients()
    }
}

extension FoodItem {
    /// Other nutrients for one serving.
    var otherNutrients: OtherNutrients {
        OtherNutrients(fiber: fiber, sugar: sugar, sodium: sodium, saturatedFat: saturatedFat,
                       potassium: potassium, cholesterol: cholesterol, alcohol: alcohol, caffeine: caffeine,
                       micros: micros)
    }
}

extension FoodLogEntry {
    /// Other nutrients for the logged amount.
    var otherNutrients: OtherNutrients {
        get {
            OtherNutrients(fiber: fiber, sugar: sugar, sodium: sodium, saturatedFat: saturatedFat,
                           potassium: potassium, cholesterol: cholesterol, alcohol: alcohol, caffeine: caffeine,
                           micros: micros)
        }
        set {
            fiber = newValue.fiber
            sugar = newValue.sugar
            sodium = newValue.sodium
            saturatedFat = newValue.saturatedFat
            potassium = newValue.potassium
            cholesterol = newValue.cholesterol
            alcohol = newValue.alcohol
            caffeine = newValue.caffeine
            micros = newValue.micros
        }
    }
}

extension SavedMealItem {
    /// Other nutrients for the saved amount; missing ones (meals saved before they were tracked) are zero.
    var otherNutrients: OtherNutrients {
        OtherNutrients(fiber: fiber ?? 0, sugar: sugar ?? 0, sodium: sodium ?? 0, saturatedFat: saturatedFat ?? 0,
                       potassium: potassium ?? 0, cholesterol: cholesterol ?? 0, alcohol: alcohol ?? 0,
                       caffeine: caffeine ?? 0, micros: micros ?? Micronutrients())
    }
}

extension Recipe {
    /// Other nutrients for one serving, from the ingredients that recorded them
    /// (ingredients matched to a saved food carry its nutrients; typed-in ones don't).
    var otherNutrientsPerServing: OtherNutrients {
        ingredients.reduce(OtherNutrients()) { $0 + ($1.otherNutrients ?? OtherNutrients()) }
            .scaled(by: 1 / Double(max(servings, 1)))
    }
}
