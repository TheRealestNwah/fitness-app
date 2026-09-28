import Foundation

/// Turns a typed or dictated sentence ("2 eggs, a slice of whole wheat toast and a black coffee")
/// into items with an amount, an optional unit and a food name, then matches each to a saved
/// food and works out how many of that food's servings it is. Runs on device and in English.
enum FoodSentenceParser {
    struct Item: Equatable {
        var quantity: Double
        /// Singular and lowercased ("slice", "cup", "g"); nil for a plain count ("2 eggs").
        var unit: String?
        var name: String
    }

    // MARK: - Parsing

    static func parse(_ sentence: String) -> [Item] {
        split(sentence).compactMap(parseItem)
    }

    /// Splits on commas, semicolons, new lines, "+", "&" and the words "and", "with" and "plus".
    static func split(_ sentence: String) -> [String] {
        let separated = sentence.lowercased()
            .replacingOccurrences(of: #"\s*(?:[,;\n+&]|\band\b|\bwith\b|\bplus\b)\s*"#, with: "|",
                                  options: .regularExpression)
        return separated.split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .filter { !$0.isEmpty }
    }

    static func parseItem(_ text: String) -> Item? {
        var words = text.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        var quantity: Double?

        // A number, possibly glued to a unit ("150g") or followed by a fraction ("1 1/2").
        if let first = words.first, let match = first.wholeMatch(of: #/(\d+(?:\.\d+)?|\d+/\d+)([a-z]*)/#) {
            quantity = number(String(match.1))
            words.removeFirst()
            if !match.2.isEmpty { words.insert(String(match.2), at: 0) }
            if let next = words.first, next.contains("/"), let fraction = number(next), fraction < 1 {
                quantity = (quantity ?? 0) + fraction
                words.removeFirst()
            }
        } else {
            // Words: "a", "two", "half an", "a couple of", "a dozen".
            // "A" only counts when nothing more specific follows it ("a couple of eggs").
            var value: Double?
            var justArticle = false
            while let word = words.first, let number = numberWords[word] {
                words.removeFirst()
                switch word {
                case "half", "quarter", "dozen":
                    value = (value ?? 1) * number
                    justArticle = false
                case "a", "an":
                    if value == nil {
                        value = 1
                        justArticle = true
                    }
                default:
                    if value == nil || justArticle { value = number }
                    justArticle = false
                }
                if words.first == "of" { words.removeFirst() }
            }
            quantity = value
        }

        var unit: String?
        if let word = words.first, let known = unitWords[singular(word)] ?? unitWords[word] {
            unit = known
            words.removeFirst()
            if words.first == "of" { words.removeFirst() }
        }
        while let word = words.first, ["of", "some", "the", "my"].contains(word) { words.removeFirst() }

        let name = words.joined(separator: " ")
        guard !name.isEmpty else { return nil }
        var amount = quantity ?? 1
        if unit == "oz" { amount *= 28.35; unit = "g" }
        if unit == "kg" { amount *= 1000; unit = "g" }
        if unit == "l" { amount *= 1000; unit = "ml" }
        return Item(quantity: amount, unit: unit, name: name)
    }

    // MARK: - Servings

    /// How many servings of a food the item is. Grams and millilitres use the metric amount in the
    /// serving description; a household unit uses a matching preset or the description's own unit
    /// ("1 slice (43 g)"); anything else counts servings.
    static func servings(for item: Item, servingDescription: String, presets: [ServingPreset] = []) -> Double {
        if let unit = item.unit {
            if unit == "g" || unit == "ml" {
                if let metric = ServingUnits.metricPerServing(servingDescription), metric.unit == unit {
                    return ServingUnits.servings(forMetric: item.quantity, per: metric)
                }
                return 1
            }
            if let preset = presets.first(where: { singular($0.label.lowercased()).hasSuffix(unit) }) {
                return item.quantity * preset.servings
            }
            if let described = describedCount(servingDescription), described.unit == unit {
                return item.quantity / described.count
            }
        }
        return item.quantity
    }

    /// "2 slices (86 g)" → (2, "slice").
    static func describedCount(_ description: String) -> (count: Double, unit: String)? {
        guard let match = description.lowercased().firstMatch(of: #/^\s*(\d+(?:\.\d+)?|\d+/\d+)\s+([a-z]+)/#),
              let count = number(String(match.1)), count > 0 else { return nil }
        let word = singular(String(match.2))
        return (count, unitWords[word] ?? word)
    }

    // MARK: - Matching

    /// The best saved food for a name: a normal search first (also in the singular), then the
    /// food sharing the most words with it ("whole wheat toast" → "Whole wheat bread").
    static func bestMatch<T>(_ name: String, in items: [T], candidate: (T) -> FoodSearchRanking.Candidate) -> T? {
        for query in [name, singularPhrase(name)] {
            if let first = FoodSearchRanking.rank(items, query: query, candidate: candidate).first { return first }
        }
        let terms = name.split(separator: " ").map(String.init).filter { $0.count >= 3 }
        guard !terms.isEmpty else { return nil }
        var best: (item: T, words: Int, score: Int)?
        for item in items {
            let scores = terms.compactMap { term in
                FoodSearchRanking.score(candidate(item), query: term)
                    ?? FoodSearchRanking.score(candidate(item), query: singular(term))
            }
            guard !scores.isEmpty else { continue }
            let total = scores.reduce(0, +)
            let isBetter = best.map { scores.count > $0.words || (scores.count == $0.words && total > $0.score) } ?? true
            if isBetter { best = (item, scores.count, total) }
        }
        guard let best, best.words * 2 >= terms.count else { return nil }
        return best.item
    }

    // MARK: - Words

    private static let numberWords: [String: Double] = [
        "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
        "eight": 8, "nine": 9, "ten": 10, "twelve": 12, "half": 0.5, "couple": 2, "few": 3, "dozen": 12,
        "quarter": 0.25,
    ]

    /// Singular spellings and abbreviations → the unit used for matching.
    private static let unitWords: [String: String] = [
        "g": "g", "gram": "g", "gr": "g", "kg": "kg", "kilo": "kg", "oz": "oz", "ounce": "oz",
        "ml": "ml", "millilitre": "ml", "milliliter": "ml", "l": "l", "litre": "l", "liter": "l",
        "cup": "cup", "mug": "mug", "glass": "glass", "bowl": "bowl", "slice": "slice", "piece": "piece",
        "serving": "serving", "portion": "serving", "handful": "handful", "can": "can", "bottle": "bottle",
        "scoop": "scoop", "tbsp": "tbsp", "tablespoon": "tbsp", "tsp": "tsp", "teaspoon": "tsp",
        "bar": "bar", "pot": "pot", "pint": "pint",
    ]

    static func singular(_ word: String) -> String {
        for suffix in ["sses", "shes", "ches", "xes"] where word.hasSuffix(suffix) {
            return String(word.dropLast(2))
        }
        if word.hasSuffix("ies"), word.count > 4 { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("s"), !word.hasSuffix("ss"), word.count > 3 { return String(word.dropLast()) }
        return word
    }

    /// "boiled eggs" → "boiled egg".
    private static func singularPhrase(_ phrase: String) -> String {
        var words = phrase.split(separator: " ").map(String.init)
        if let last = words.popLast() { words.append(singular(last)) }
        return words.joined(separator: " ")
    }

    private static func number(_ text: String) -> Double? {
        let parts = text.split(separator: "/")
        if parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 { return n / d }
        return Double(text.replacingOccurrences(of: ",", with: "."))
    }
}
