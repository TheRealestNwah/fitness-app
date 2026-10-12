import Foundation

/// How nutrient amounts are written, so the same number reads the same on every screen.
enum NutrientText {
    /// Grams for a macro target or total. Rounded rather than truncated, so the plan summary,
    /// Today, Food and Plan agree (118.7 g is 119 g everywhere).
    static func grams(_ value: Double) -> Int { Int(value.rounded()) }

    /// "12 g", or "12 / 30 g" against a goal. Nutrients are stored as 0 when a food doesn't list
    /// them, so a total of 0 shows as "–" rather than claiming a measured zero.
    static func amount(_ value: Double, unit: String, goal: Double?, fractionDigits: Int = 0) -> String {
        let listed = value > 0
        let number = listed ? value.formatted(.number.precision(.fractionLength(0...fractionDigits))) : "–"
        guard let goal, goal > 0 else { return unit.isEmpty || !listed ? number : "\(number) \(unit)" }
        return "\(number) / \(Int(goal.rounded())) \(unit)"
    }
}
