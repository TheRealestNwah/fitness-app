import Foundation

/// Combines free-text ingredient amounts ("1/2 cup (40 g)", "2 large", "120 g") into a
/// grocery-list line, summing quantities that share a unit.
enum GroceryAggregator {
    struct Quantity: Equatable {
        var value: Double
        var unit: String
    }

    /// Parses an amount into a number and unit. A metric weight or volume in brackets
    /// ("1 tbsp (14 g)") wins over the household measure so different spoons still add up.
    static func parse(_ amount: String) -> Quantity? {
        let text = amount.trimmingCharacters(in: .whitespaces)
        if let match = firstMatch(#"\(\s*(\d+(?:\.\d+)?)\s*(g|kg|ml|l)\s*\)"#, in: text),
           let value = Double(match[1]) {
            return normalized(Quantity(value: value, unit: match[2]))
        }
        guard let match = firstMatch(#"^(\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)\s*(.*)$"#, in: text),
              let value = number(match[1]) else { return nil }
        return normalized(Quantity(value: value, unit: match[2].trimmingCharacters(in: .whitespaces)))
    }

    /// Scales each amount by its multiplier, sums those with the same unit and returns one
    /// display string per unit, in first-seen order. Amounts that can't be parsed are kept as-is.
    static func combine(_ amounts: [(amount: String, multiplier: Double)]) -> [String] {
        var totals: [String: Quantity] = [:]
        var order: [String] = []
        var unparsed: [String] = []
        for (amount, multiplier) in amounts {
            if let quantity = parse(amount) {
                let key = unitKey(quantity.unit)
                if totals[key] == nil {
                    order.append(key)
                    totals[key] = Quantity(value: 0, unit: String(quantity.unit.prefix(key.count)))
                }
                totals[key]?.value += quantity.value * multiplier
            } else {
                let text = multiplier == 1 ? amount : "\(amount) × \(format(multiplier))"
                if !unparsed.contains(text) { unparsed.append(text) }
            }
        }
        return order.compactMap { totals[$0].map(display) } + unparsed
    }

    static func display(_ quantity: Quantity) -> String {
        let value = ["g", "ml"].contains(quantity.unit) ? quantity.value.rounded() : quantity.value
        let number = format(value)
        guard !quantity.unit.isEmpty else { return number }
        return "\(number) \(value > 1 ? plural(quantity.unit) : quantity.unit)"
    }

    // MARK: - Helpers

    private static func normalized(_ quantity: Quantity) -> Quantity {
        switch quantity.unit.lowercased() {
        case "g", "gram", "grams": return Quantity(value: quantity.value, unit: "g")
        case "kg": return Quantity(value: quantity.value * 1000, unit: "g")
        case "ml": return Quantity(value: quantity.value, unit: "ml")
        case "l": return Quantity(value: quantity.value * 1000, unit: "ml")
        default: return quantity
        }
    }

    /// "slice" and "slices" count as the same unit.
    private static func unitKey(_ unit: String) -> String {
        let lower = unit.lowercased()
        return lower.count > 3 && lower.hasSuffix("s") ? String(lower.dropLast()) : lower
    }

    private static let unpluralized: Set<String> = ["g", "ml", "oz", "lb", "tsp", "tbsp", "large", "medium", "small", "whole"]

    private static func plural(_ unit: String) -> String {
        let last = unit.split(separator: " ").last.map(String.init) ?? unit
        guard !unpluralized.contains(last.lowercased()), !last.hasSuffix("s"),
              last.allSatisfy(\.isLetter) else { return unit }
        return unit + "s"
    }

    private static func number(_ text: String) -> Double? {
        let parts = text.split(separator: " ")
        var total = 0.0
        for part in parts {
            let fraction = part.split(separator: "/")
            if fraction.count == 2 {
                guard let n = Double(fraction[0]), let d = Double(fraction[1]), d != 0 else { return nil }
                total += n / d
            } else {
                guard let value = Double(part) else { return nil }
                total += value
            }
        }
        return total
    }

    private static func format(_ value: Double) -> String {
        let text = String(format: "%.2f", value)
        return text.contains(".")
            ? String(text.reversed().drop(while: { $0 == "0" }).drop(while: { $0 == "." }).reversed())
            : text
    }

    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }
}
