import Foundation

/// Reads a recipe from a web page's schema.org JSON-LD, which most recipe sites publish.
enum RecipeImporter {
    struct Imported: Equatable {
        var name: String
        var servings: Int
        var prepMinutes: Int
        var ingredients: [String]
        var instructions: String
        /// Per-serving nutrition, when the page lists it.
        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?
    }

    enum ImportError: LocalizedError {
        case badURL, network, noRecipe

        var errorDescription: String? {
            switch self {
            case .badURL: return "That doesn't look like a web address."
            case .network: return "Couldn't load that page. Check the address and your connection."
            case .noRecipe: return "No recipe found on that page. Many sites publish one, but not all."
            }
        }
    }

    static func fetch(_ address: String) async throws -> Imported {
        var text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.lowercased().hasPrefix("http") { text = "https://" + text }
        guard let url = URL(string: text), url.host != nil else { throw ImportError.badURL }
        let data: Data
        do {
            data = try await URLSession.shared.data(from: url).0
        } catch {
            throw ImportError.network
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
              let recipe = parse(html: html) else { throw ImportError.noRecipe }
        return recipe
    }

    static func parse(html: String) -> Imported? {
        let pattern = #"<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        else { return nil }
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range(at: 1), in: html),
                  let json = try? JSONSerialization.jsonObject(with: Data(html[range].utf8)),
                  let object = findRecipe(json) else { continue }
            return imported(from: object)
        }
        return nil
    }

    private static func findRecipe(_ json: Any) -> [String: Any]? {
        if let array = json as? [Any] {
            return array.lazy.compactMap(findRecipe).first
        }
        guard let object = json as? [String: Any] else { return nil }
        let type = object["@type"]
        if (type as? String) == "Recipe" || ((type as? [String])?.contains("Recipe") ?? false) { return object }
        if let graph = object["@graph"] { return findRecipe(graph) }
        return nil
    }

    private static func imported(from object: [String: Any]) -> Imported? {
        let name = clean(object["name"] as? String ?? "")
        let ingredients = (object["recipeIngredient"] as? [String] ?? object["ingredients"] as? [String] ?? [])
            .map(clean).filter { !$0.isEmpty }
        guard !name.isEmpty, !ingredients.isEmpty else { return nil }
        let nutrition = object["nutrition"] as? [String: Any] ?? [:]
        return Imported(name: name,
                        servings: servings(object["recipeYield"]),
                        prepMinutes: minutes(object["totalTime"] ?? object["prepTime"]),
                        ingredients: ingredients,
                        instructions: instructions(object["recipeInstructions"]),
                        calories: firstNumber(nutrition["calories"]),
                        protein: firstNumber(nutrition["proteinContent"]),
                        carbs: firstNumber(nutrition["carbohydrateContent"]),
                        fat: firstNumber(nutrition["fatContent"]))
    }

    /// "4", "4 servings", ["4", "4 servings"], 4.
    static func servings(_ value: Any?) -> Int {
        if let array = value as? [Any] { return array.lazy.map { servings($0) }.first { $0 > 1 } ?? servings(array.first) }
        if let n = value as? Int { return max(n, 1) }
        return max(Int(firstNumber(value) ?? 1), 1)
    }

    /// ISO 8601 durations like "PT1H15M".
    static func minutes(_ value: Any?) -> Int {
        guard let text = value as? String, text.hasPrefix("P") else { return 15 }
        var total = 0, number = ""
        for char in text {
            if char.isNumber { number.append(char); continue }
            let n = Int(number) ?? 0
            number = ""
            switch char {
            case "D": total += n * 1440
            case "H": total += n * 60
            case "M": total += n
            default: break
            }
        }
        return total > 0 ? total : 15
    }

    private static func instructions(_ value: Any?) -> String {
        if let text = value as? String { return clean(text) }
        guard let steps = value as? [Any] else { return "" }
        var lines: [String] = []
        for step in steps {
            if let text = step as? String {
                lines.append(clean(text))
            } else if let object = step as? [String: Any] {
                if let items = object["itemListElement"] {
                    let nested = instructions(items)
                    if !nested.isEmpty { lines.append(nested) }
                } else if let text = object["text"] as? String {
                    lines.append(clean(text))
                }
            }
        }
        return lines.filter { !$0.isEmpty }.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }

    static func firstNumber(_ value: Any?) -> Double? {
        if let n = value as? Double { return n }
        if let n = value as? Int { return Double(n) }
        guard let text = value as? String,
              let match = text.range(of: #"\d+(?:\.\d+)?"#, options: .regularExpression) else { return nil }
        return Double(text[match])
    }

    /// Decodes the handful of HTML entities recipe sites leave in JSON-LD and collapses whitespace.
    static func clean(_ text: String) -> String {
        var s = text
        for (entity, char) in [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&nbsp;", " "),
                               ("&frac12;", "½"), ("&frac14;", "¼"), ("&frac34;", "¾")] {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        s = s.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        return s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
