import Foundation

/// Alcohol conversions. Diary values are grams of pure alcohol; Apple Health and people think in
/// standard drinks.
enum Alcohol {
    /// A US standard drink: 14 g of pure alcohol (a 12 oz beer, 5 oz of wine or a 1.5 oz shot).
    static let standardDrinkG = 14.0
    /// Density of ethanol, g/ml.
    static let densityGPerMl = 0.789
    static let kcalPerGram = 7.0

    static func standardDrinks(grams: Double) -> Double {
        max(grams, 0) / standardDrinkG
    }

    /// Grams of alcohol in `millilitres` of a drink that is `percentABV` alcohol by volume.
    static func grams(percentABV: Double, millilitres: Double) -> Double {
        max(percentABV, 0) / 100 * max(millilitres, 0) * densityGPerMl
    }
}

enum Caffeine {
    /// The amount generally considered safe for healthy adults per day (US FDA guidance);
    /// shown as a reference limit in the diary.
    static let dailyLimitMg = 400.0
}
