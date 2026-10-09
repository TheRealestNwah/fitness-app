import Foundation

enum FoodDataCentralError: LocalizedError {
    case rateLimited
    case badKey
    case network(Error)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .rateLimited: return "USDA search is busy. Add your own free USDA key in Settings to avoid shared limits."
        case .badKey: return "The USDA API key was rejected. Check it in Settings."
        case .network: return "Couldn't reach USDA FoodData Central."
        case .badResponse: return "USDA FoodData Central sent something unexpected."
        }
    }
}

/// Searches USDA FoodData Central (https://fdc.nal.usda.gov), the US government's public-domain
/// nutrient database: generic foods (Foundation, SR Legacy) and branded products.
enum FoodDataCentralClient {
    /// Shared, heavily rate-limited key USDA provides for trying the API.
    static let demoKey = "DEMO_KEY"
    static let signupURL = URL(string: "https://fdc.nal.usda.gov/api-key-signup")!

    static func searchURL(for query: String, apiKey: String, limit: Int) -> URL {
        var comps = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        comps.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: String(limit)),
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy,Branded"),
            URLQueryItem(name: "api_key", value: apiKey.isEmpty ? demoKey : apiKey)
        ]
        return comps.url!
    }

    static func search(_ query: String, apiKey: String, limit: Int = 25,
                       session: URLSession = .shared) async throws -> [ScannedProduct] {
        var request = URLRequest(url: searchURL(for: query, apiKey: apiKey, limit: limit))
        request.setValue(OpenFoodFactsClient.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FoodDataCentralError.network(error)
        }
        switch (response as? HTTPURLResponse)?.statusCode {
        case 429: throw FoodDataCentralError.rateLimited
        case 400, 401, 403: throw FoodDataCentralError.badKey
        default: break
        }
        return try parse(data)
    }

    /// Generic foods first (they're the ones people usually mean), each group in USDA's relevance order.
    static func parse(_ data: Data) throws -> [ScannedProduct] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let foods = root["foods"] as? [[String: Any]] else {
            throw FoodDataCentralError.badResponse
        }
        let parsed = foods.compactMap { food -> (branded: Bool, product: ScannedProduct)? in
            guard let product = parseFood(food) else { return nil }
            return ((food["dataType"] as? String) == "Branded", product)
        }
        return parsed.filter { !$0.branded }.map(\.product) + parsed.filter(\.branded).map(\.product)
    }

    /// One search hit. Nutrient values are per 100 g; branded foods are scaled to their label serving.
    static func parseFood(_ food: [String: Any]) -> ScannedProduct? {
        guard let rawName = (food["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawName.isEmpty else { return nil }

        var values: [Int: Double] = [:]
        for nutrient in food["foodNutrients"] as? [[String: Any]] ?? [] {
            guard let nutrientID = nutrient["nutrientId"] as? Int else { continue }
            if let v = nutrient["value"] as? Double { values[nutrientID] = v }
            else if let v = nutrient["value"] as? Int { values[nutrientID] = Double(v) }
        }
        // 1008 is energy in kcal; Foundation foods often give the Atwater factors (2047, 2048) instead.
        guard let per100 = values[1008] ?? values[2047] ?? values[2048] ?? values[1062].map({ $0 / 4.184 }) else {
            return nil
        }

        var factor = 1.0
        var serving = "100 g"
        let size = food["servingSize"] as? Double ?? (food["servingSize"] as? Int).map(Double.init)
        let unit = (food["servingSizeUnit"] as? String)?.lowercased()
        if let size, size > 0, let unit, ["g", "grm", "ml", "mlt"].contains(unit) {
            factor = size / 100
            let amount = "\(size.formatted(.number.precision(.fractionLength(0...1)))) \(unit.hasPrefix("m") ? "ml" : "g")"
            let household = (food["householdServingFullText"] as? String)?
                .trimmingCharacters(in: .whitespaces).lowercased() ?? ""
            serving = household.isEmpty ? amount : "\(household) (\(amount))"
        }

        func value(_ ids: Int...) -> Double {
            (ids.compactMap { values[$0] }.first ?? 0) * factor
        }
        let brand = ((food["brandName"] as? String) ?? (food["brandOwner"] as? String) ?? "")
            .trimmingCharacters(in: .whitespaces)
        let barcode = (food["gtinUpc"] as? String).flatMap(OpenFoodFactsClient.normalise) ?? ""
        return ScannedProduct(barcode: barcode, name: tidy(rawName), brand: tidy(brand), servingDescription: serving,
                              calories: per100 * factor,
                              protein: value(1003), carbs: value(1005), fat: value(1004), fiber: value(1079),
                              sugar: value(2000, 1063), sodium: value(1093),
                              saturatedFat: value(1258), potassium: value(1092), cholesterol: value(1253),
                              alcohol: value(1018), caffeine: value(1057))
    }

    /// Branded entries arrive in capitals ("KIND BARS"); everything else is left as written.
    private static func tidy(_ text: String) -> String {
        text == text.uppercased() ? text.capitalized : text
    }
}
