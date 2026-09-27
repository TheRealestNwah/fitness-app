import Foundation

/// A packaged food as returned by Open Food Facts, reduced to what the diary needs.
struct ScannedProduct: Equatable {
    var barcode: String
    var name: String
    var brand: String
    var servingDescription: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double = 0
    /// Milligrams.
    var sodium: Double = 0

    func makeFoodItem() -> FoodItem {
        let item = FoodItem(name: name, brand: brand, servingDescription: servingDescription,
                            calories: calories, protein: protein, carbs: carbs, fat: fat, fiber: fiber,
                            sugar: sugar, sodium: sodium, isCustom: true)
        item.barcode = barcode
        return item
    }
}

enum OpenFoodFactsError: LocalizedError {
    case badBarcode
    case network(Error)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .badBarcode: return "That doesn't look like a product barcode."
        case .network: return "Couldn't reach the food database. Check your connection and try again."
        case .badResponse: return "The food database sent something unexpected."
        }
    }
}

/// Looks up barcodes on Open Food Facts (https://world.openfoodfacts.org), a free, open product database.
enum OpenFoodFactsClient {
    static let userAgent = "Stride iOS/1.0 (open-source weight-loss app)"

    static func normalise(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard (6...14).contains(digits.count) else { return nil }
        return digits
    }

    static func url(for barcode: String) -> URL {
        var comps = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json")!
        comps.queryItems = [URLQueryItem(name: "fields", value: "code,product_name,brands,serving_size,serving_quantity,nutriments")]
        return comps.url!
    }

    /// Returns nil when the database has no entry for the barcode.
    static func product(barcode raw: String, session: URLSession = .shared) async throws -> ScannedProduct? {
        guard let barcode = normalise(raw) else { throw OpenFoodFactsError.badBarcode }
        var request = URLRequest(url: url(for: barcode))
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw OpenFoodFactsError.network(error)
        }
        return try parse(data, barcode: barcode)
    }

    /// Pure parsing of the v2 product JSON. Nutriment values arrive as numbers or strings, so read them loosely.
    static func parse(_ data: Data, barcode: String) throws -> ScannedProduct? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenFoodFactsError.badResponse
        }
        let status = (root["status"] as? Int) ?? (Int((root["status"] as? String) ?? "") ?? 0)
        guard status == 1, let product = root["product"] as? [String: Any] else { return nil }

        let nutriments = product["nutriments"] as? [String: Any] ?? [:]
        func number(_ key: String) -> Double? {
            if let d = nutriments[key] as? Double { return d }
            if let i = nutriments[key] as? Int { return Double(i) }
            if let s = nutriments[key] as? String { return Double(s) }
            return nil
        }
        func kcal(_ suffix: String) -> Double? {
            if let k = number("energy-kcal\(suffix)") { return k }
            if let kj = number("energy-kj\(suffix)") { return kj / 4.184 }
            if let e = number("energy\(suffix)"), (nutriments["energy_unit"] as? String)?.lowercased() == "kcal" { return e }
            if let e = number("energy\(suffix)") { return e / 4.184 }
            return nil
        }

        // Open Food Facts gives sodium and salt in grams; salt is 2.5 × sodium.
        func sodiumMg(_ suffix: String) -> Double? {
            if let g = number("sodium\(suffix)") { return g * 1000 }
            if let salt = number("salt\(suffix)") { return salt / 2.5 * 1000 }
            return nil
        }

        let name = (product["product_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let brand = ((product["brands"] as? String) ?? "")
            .split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        guard !name.isEmpty else { return nil }

        let servingSize = (product["serving_size"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        var servingQuantity: Double? = nil
        if let q = product["serving_quantity"] as? Double { servingQuantity = q }
        else if let q = product["serving_quantity"] as? Int { servingQuantity = Double(q) }
        else if let q = product["serving_quantity"] as? String { servingQuantity = Double(q) }

        // Prefer values given per serving; otherwise scale per-100 g values by the serving quantity; otherwise use 100 g.
        if let perServing = kcal("_serving"), !servingSize.isEmpty {
            return ScannedProduct(barcode: barcode, name: name, brand: brand, servingDescription: servingSize,
                                  calories: perServing,
                                  protein: number("proteins_serving") ?? 0,
                                  carbs: number("carbohydrates_serving") ?? 0,
                                  fat: number("fat_serving") ?? 0,
                                  fiber: number("fiber_serving") ?? 0,
                                  sugar: number("sugars_serving") ?? 0,
                                  sodium: sodiumMg("_serving") ?? 0)
        }
        guard let per100 = kcal("_100g") else { return nil }
        let factor: Double
        let description: String
        if let q = servingQuantity, q > 0, !servingSize.isEmpty {
            factor = q / 100
            description = servingSize
        } else {
            factor = 1
            description = "100 g"
        }
        return ScannedProduct(barcode: barcode, name: name, brand: brand, servingDescription: description,
                              calories: per100 * factor,
                              protein: (number("proteins_100g") ?? 0) * factor,
                              carbs: (number("carbohydrates_100g") ?? 0) * factor,
                              fat: (number("fat_100g") ?? 0) * factor,
                              fiber: (number("fiber_100g") ?? 0) * factor,
                              sugar: (number("sugars_100g") ?? 0) * factor,
                              sodium: (sodiumMg("_100g") ?? 0) * factor)
    }
}
