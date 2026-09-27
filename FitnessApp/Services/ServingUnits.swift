import Foundation

enum ServingUnits {
    /// Grams or millilitres in one serving, when the description says:
    /// "100 g", "1 slice (43 g)", "1 cup (240 ml)", "0.5 kg". Nil for "1 medium" or "handful".
    static func metricPerServing(_ description: String) -> GroceryAggregator.Quantity? {
        guard let quantity = GroceryAggregator.parse(description),
              quantity.unit == "g" || quantity.unit == "ml", quantity.value > 0 else { return nil }
        return quantity
    }

    /// Servings for an amount in the metric unit, and back.
    static func servings(forMetric amount: Double, per serving: GroceryAggregator.Quantity) -> Double {
        amount / serving.value
    }

    static func metric(forServings servings: Double, per serving: GroceryAggregator.Quantity) -> Double {
        servings * serving.value
    }

    /// A per-100 g label value scaled to one serving of `servingGrams`.
    static func perServing(fromPer100 value: Double, servingGrams: Double) -> Double {
        value * servingGrams / 100
    }
}
