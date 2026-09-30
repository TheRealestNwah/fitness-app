import Foundation

/// Turns the text read from a photo of a printed recipe (a cookbook page, a recipe card) into a
/// draft recipe: title, servings, time, ingredient lines and method. Runs on device, in English.
enum RecipeTextParser {
    private static let ingredientHeadings = ["ingredients", "you will need", "you'll need", "what you need"]
    private static let methodHeadings = ["method", "directions", "instructions", "preparation", "steps", "to make",
                                         "how to make it"]

    static func parse(lines raw: [String]) -> RecipeImporter.Imported? {
        let lines = raw.map(clean).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        let servingCount = lines.lazy.compactMap { self.servings(in: $0) }.first ?? 0
        // A total time wins; otherwise prep and cook times add up.
        let timed = lines.compactMap { line in self.minutes(in: line).map { (line: line.lowercased(), minutes: $0) } }
        let prepMinutes = timed.first { $0.line.contains("total") || $0.line.contains("ready in") }?.minutes
            ?? timed.reduce(0) { $0 + $1.minutes }

        let ingredientStart = lines.firstIndex { isHeading($0, ingredientHeadings) }
        let methodStart = lines.firstIndex { isHeading($0, methodHeadings) }
        var ingredients: [String] = []
        var method: [String] = []
        var titleArea: [String]

        if let ingredientStart {
            let ingredientEnd = methodStart.map { $0 > ingredientStart ? $0 : lines.count } ?? lines.count
            titleArea = Array(lines[..<ingredientStart])
            let block = Array(lines[(ingredientStart + 1)..<ingredientEnd])
            if methodStart == nil {
                // No method heading: ingredients run until the first sentence-like line.
                let split = block.firstIndex(where: looksLikeStep) ?? block.count
                ingredients = Array(block[..<split])
                method = Array(block[split...])
            } else {
                ingredients = block
            }
            if let methodStart, methodStart > ingredientStart {
                method += lines[(methodStart + 1)...]
            }
        } else {
            // No headings: sort lines by shape.
            titleArea = []
            for (index, line) in lines.enumerated() {
                if looksLikeIngredient(line) {
                    ingredients.append(line)
                } else if looksLikeStep(line) || !ingredients.isEmpty {
                    method.append(line)
                } else if index < 3 {
                    titleArea.append(line)
                }
            }
        }

        ingredients = ingredients.filter { servings(in: $0) == nil && minutes(in: $0) == nil && !isHeading($0, methodHeadings) }
        guard !ingredients.isEmpty else { return nil }
        let title = (titleArea.isEmpty ? Array(lines.prefix(2)) : titleArea)
            .first { line in
                line.count <= 60 && line.contains(where: \.isLetter) && servings(in: line) == nil
                    && minutes(in: line) == nil && !looksLikeIngredient(line)
                    && !isHeading(line, ingredientHeadings) && !isHeading(line, methodHeadings)
            } ?? ""
        return RecipeImporter.Imported(name: title, servings: max(servingCount, 1), prepMinutes: prepMinutes,
                                       ingredients: ingredients, instructions: joinSteps(method))
    }

    // MARK: - Lines

    /// Trims bullets and turns fraction characters into text the food parser reads ("½" → "1/2").
    static func clean(_ line: String) -> String {
        var text = line
        for (glyph, plain) in fractions {
            text = text.replacingOccurrences(of: "(\\d)\(glyph)", with: "$1 \(plain)", options: .regularExpression)
            text = text.replacingOccurrences(of: glyph, with: plain)
        }
        text = text.replacingOccurrences(of: #"^\s*[•·▪◦*\-–—]\s*"#, with: "", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespaces)
    }

    private static let fractions = [("½", "1/2"), ("⅓", "1/3"), ("⅔", "2/3"), ("¼", "1/4"), ("¾", "3/4"), ("⅛", "1/8")]

    static func isHeading(_ line: String, _ words: [String]) -> Bool {
        let lower = line.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        return words.contains(lower) || words.contains { lower.hasPrefix($0 + " ") && lower.count <= $0.count + 12 }
    }

    /// "2 cups flour", "1/2 tsp salt", "3 eggs", "a pinch of salt".
    static func looksLikeIngredient(_ line: String) -> Bool {
        guard line.count <= 80 else { return false }
        let lower = line.lowercased()
        if lower.first?.isNumber == true {
            // "1. Preheat the oven" is a step, not an ingredient ("1.5 kg potatoes" is).
            return lower.wholeMatch(of: #/\d+[.)]\s+.*/#) == nil
        }
        return lower.hasPrefix("a pinch") || lower.hasPrefix("pinch") || lower.hasPrefix("handful")
            || lower.hasSuffix("to taste")
    }

    /// Numbered steps and full sentences.
    static func looksLikeStep(_ line: String) -> Bool {
        if line.wholeMatch(of: #/(?:step\s*)?\d+[.):]\s+.+/#.ignoresCase()) != nil { return true }
        return line.count > 45 && line.split(separator: " ").count >= 8
    }

    static func servings(in line: String) -> Int? {
        let lower = line.lowercased()
        let patterns = [#/(?:serves|servings?:?|makes|yield:?|portions?:?)\s*(\d+)/#, #/(\d+)\s*(?:servings|portions)/#]
        for pattern in patterns {
            if let match = lower.firstMatch(of: pattern), let value = Int(match.1), (1...50).contains(value) {
                return value
            }
        }
        return nil
    }

    /// Minutes in a "Prep 15 min" / "Cook: 1 hr 10 mins" line; nil for lines that aren't about time.
    static func minutes(in line: String) -> Int? {
        let lower = line.lowercased()
        // Short labelled lines only, so a step like "Cook for 10 minutes" isn't counted.
        guard line.count <= 40, !looksLikeStep(line),
              lower.contains("prep") || lower.contains("cook") || lower.contains("time") || lower.contains("ready in")
        else { return nil }
        var total = 0
        if let hours = lower.firstMatch(of: #/(\d+)\s*(?:h|hr|hrs|hour|hours)\b/#), let h = Int(hours.1) { total += h * 60 }
        if let mins = lower.firstMatch(of: #/(\d+)\s*(?:m|min|mins|minute|minutes)\b/#), let m = Int(mins.1) { total += m }
        return total > 0 ? total : nil
    }

    /// Step lines, rejoining sentences the page wrapped over several lines.
    static func joinSteps(_ lines: [String]) -> String {
        var steps: [String] = []
        for line in lines {
            if steps.isEmpty || looksLikeStep(line) && line.first?.isNumber == true
                || steps.last?.hasSuffix(".") == true && line.first?.isUppercase == true {
                steps.append(line)
            } else {
                steps[steps.count - 1] += " " + line
            }
        }
        return steps.joined(separator: "\n")
    }
}

/// Fills in an ingredient's nutrition from the closest saved food, when there is one.
enum RecipeIngredientMatcher {
    static func ingredient(for line: String, foods: [FoodItem]) -> Ingredient {
        guard let item = FoodSentenceParser.parseItem(line),
              let food = FoodSentenceParser.bestMatch(item.name, in: foods, candidate: {
                  .init(name: $0.name, other: [$0.brand], isFavorite: $0.isFavorite, lastUsed: $0.lastUsed)
              }) else {
            return Ingredient(name: line, amount: "", calories: 0, protein: 0, carbs: 0, fat: 0)
        }
        let servings = FoodSentenceParser.servings(for: item, servingDescription: food.servingDescription,
                                                   presets: food.servingPresets)
        return Ingredient(name: line, amount: "\(servings.cleanString) × \(food.displayName) (\(food.servingDescription))",
                          calories: food.calories * servings, protein: food.protein * servings,
                          carbs: food.carbs * servings, fat: food.fat * servings)
    }
}
