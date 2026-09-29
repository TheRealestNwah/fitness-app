import Foundation

/// Reads nutrition values from the text of a label photo (see LabelTextRecognizer): US
/// "Nutrition Facts" panels and EU/UK tables with per-100 g and per-serving columns.
enum NutritionLabelParser {
    struct Label: Equatable {
        /// True when the numbers are per 100 g / 100 ml (the first column of an EU/UK table).
        var per100g = false
        var servingDescription: String?
        var servingGrams: Double?
        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?
        var fiber: Double?
        var sugar: Double?
        var sodiumMg: Double?
        var saturatedFat: Double?
        var potassiumMg: Double?
        var cholesterolMg: Double?

        var isEmpty: Bool { calories == nil && protein == nil && carbs == nil && fat == nil }
    }

    /// Numbers in a line, in order, with the unit that follows each ("g", "mg", "kcal", "kj", or "").
    static func amounts(in line: String) -> [(value: Double, unit: String)] {
        let pattern = #"(\d+(?:[.,]\d+)?)\s*(mg|g|kcal|kj|cal)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let ns = line as NSString
        return regex.matches(in: line, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let number = ns.substring(with: m.range(at: 1)).replacingOccurrences(of: ",", with: ".")
            guard let value = Double(number) else { return nil }
            let unit = m.range(at: 2).location == NSNotFound ? "" : ns.substring(with: m.range(at: 2)).lowercased()
            return (value, unit)
        }
    }

    static func parse(_ lines: [String]) -> Label {
        var label = Label()
        let lower = lines.map { $0.lowercased() }
        let text = lower.joined(separator: "\n")
        label.per100g = text.contains("100g") || text.contains("100 g") || text.contains("100ml") || text.contains("100 ml")

        // First mass amount on the line (the per-100 g column on EU labels), skipping percentages.
        func grams(_ line: String) -> Double? {
            let found = amounts(in: line.replacingOccurrences(of: #"\d+\s*%"#, with: "", options: .regularExpression))
            if let g = found.first(where: { $0.unit == "g" }) { return g.value }
            if let mg = found.first(where: { $0.unit == "mg" }) { return mg.value / 1000 }
            return found.first(where: { $0.unit == "" })?.value
        }

        for (i, line) in lower.enumerated() {
            let next = i + 1 < lower.count ? lower[i + 1] : ""
            if label.servingDescription == nil, line.contains("serving size") || line.hasPrefix("per serving") {
                let original = lines[i]
                if let range = original.range(of: "serving size", options: .caseInsensitive) {
                    let rest = original[range.upperBound...].trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ":")))
                    if !rest.isEmpty { label.servingDescription = rest }
                }
                if let g = amounts(in: line).first(where: { $0.unit == "g" }) { label.servingGrams = g.value }
            }
            if label.calories == nil, line.contains("energy") || line.hasPrefix("calories") || line.contains(" calories") {
                if line.contains("from fat") { continue }
                let found = amounts(in: line) + (amounts(in: line).isEmpty ? amounts(in: next) : [])
                if let kcal = found.first(where: { $0.unit == "kcal" || $0.unit == "cal" }) {
                    label.calories = kcal.value
                } else if let kj = found.first(where: { $0.unit == "kj" }) {
                    // kJ alone: the kcal figure may be on the next line.
                    if let kcal = amounts(in: next).first(where: { $0.unit == "kcal" }) { label.calories = kcal.value }
                    else { label.calories = (kj.value / 4.184).rounded() }
                } else if let plain = found.first(where: { $0.unit == "" }) {
                    label.calories = plain.value
                }
            } else if line.contains("saturate"), !line.contains("unsaturate"), !line.contains("trans") {
                // "Saturated Fat 3g" (US) or "of which saturates 3g" (EU); before the fat check below.
                if label.saturatedFat == nil { label.saturatedFat = grams(line) }
            } else if label.cholesterolMg == nil, line.contains("cholesterol") {
                label.cholesterolMg = grams(line).map { ($0 * 1000).rounded() }
            } else if label.potassiumMg == nil, line.contains("potassium") {
                label.potassiumMg = grams(line).map { ($0 * 1000).rounded() }
            } else if label.fat == nil, line.hasPrefix("fat") || line.contains("total fat") {
                label.fat = grams(line)
            } else if label.carbs == nil, line.contains("carbohydrate") || line.hasPrefix("carbs") {
                label.carbs = grams(line)
            } else if label.fiber == nil, line.contains("fiber") || line.contains("fibre") {
                label.fiber = grams(line)
            } else if label.sugar == nil, line.contains("sugar"), !line.contains("added") {
                label.sugar = grams(line)
            } else if label.protein == nil, line.contains("protein") {
                label.protein = grams(line)
            } else if label.sodiumMg == nil, line.contains("sodium") {
                label.sodiumMg = grams(line).map { ($0 * 1000).rounded() }
            } else if label.sodiumMg == nil, line.hasPrefix("salt") {
                // Salt is 2.5 × sodium.
                label.sodiumMg = grams(line).map { ($0 / 2.5 * 1000).rounded() }
            }
        }
        // EU/UK: the serving column's weight, e.g. "Per 30g serving" or "per portion (30 g)".
        if label.servingGrams == nil,
           let match = text.range(of: #"(\d+(?:[.,]\d+)?)\s*g\s*(?:serving|portion)|(?:serving|portion)\s*\(?\s*(\d+(?:[.,]\d+)?)\s*g"#,
                                  options: .regularExpression) {
            label.servingGrams = amounts(in: String(text[match])).first(where: { $0.unit == "g" })?.value
        }
        // A US panel mentions 100 g only in passing; trust a serving size when there's one.
        if label.per100g, label.servingDescription != nil, !text.contains("per 100"), !text.contains("/100") {
            label.per100g = false
        }
        return label
    }
}
