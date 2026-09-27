import Foundation

/// Rescales free-text ingredient amounts: the leading quantity ("1/2 cup", "2 large",
/// "1 1/2 tbsp") and any metric weight in brackets ("(40 g)"). Text without a number is kept.
enum RecipeScaler {
    static func scale(_ amount: String, by factor: Double) -> String {
        guard factor > 0, abs(factor - 1) > 0.0001 else { return amount }
        var text = amount
        // Bracketed metric first, so its number isn't mistaken for the leading one.
        if let regex = try? NSRegularExpression(pattern: #"\(\s*(\d+(?:\.\d+)?)\s*(g|kg|ml|l)\s*\)"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text), let value = Double(text[range]) {
            text.replaceSubrange(range, with: formatMetric(value * factor))
        }
        if let regex = try? NSRegularExpression(pattern: #"^\s*(\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text), let value = number(String(text[range])) {
            let unit = text[range.upperBound...].trimmingCharacters(in: .whitespaces).lowercased()
            let metric = ["g", "kg", "ml", "l"].contains { unit == $0 || unit.hasPrefix($0 + " ") }
            text.replaceSubrange(range, with: metric ? formatMetric(value * factor) : formatQuantity(value * factor))
        }
        return text
    }

    /// Whole grams/millilitres, or one decimal under 10.
    static func formatMetric(_ value: Double) -> String {
        value < 10 ? trimmed(value, places: 1) : String(Int(value.rounded()))
    }

    /// Kitchen fractions where they fit ("1½", "¾"), otherwise up to two decimals.
    static func formatQuantity(_ value: Double) -> String {
        let whole = Int(value)
        let fraction = value - Double(whole)
        let glyphs: [(Double, String)] = [(0, ""), (0.25, "¼"), (1.0 / 3, "⅓"), (0.5, "½"), (2.0 / 3, "⅔"), (0.75, "¾"), (1, "")]
        if let best = glyphs.min(by: { abs($0.0 - fraction) < abs($1.0 - fraction) }),
           abs(best.0 - fraction) < 0.04 {
            let base = whole + (best.0 == 1 ? 1 : 0)
            if best.1.isEmpty { return base == 0 ? trimmed(value, places: 2) : String(base) }
            return base == 0 ? best.1 : "\(base)\(best.1)"
        }
        return trimmed(value, places: 2)
    }

    private static func trimmed(_ value: Double, places: Int) -> String {
        var text = String(format: "%.\(places)f", value)
        while text.contains("."), text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    private static func number(_ text: String) -> Double? {
        var total = 0.0
        for part in text.split(separator: " ") {
            let pieces = part.split(separator: "/")
            if pieces.count == 2, let n = Double(pieces[0]), let d = Double(pieces[1]), d != 0 {
                total += n / d
            } else if let v = Double(part) {
                total += v
            } else {
                return nil
            }
        }
        return total
    }
}
