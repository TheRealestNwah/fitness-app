import Foundation

/// A food found by searching an online database, before it's saved to the device.
struct OnlineFood: Identifiable, Equatable {
    enum Source: String {
        case usda = "USDA"
        case openFoodFacts = "Open Food Facts"
    }

    let source: Source
    let product: ScannedProduct

    var id: String { "\(source.rawValue)|\(product.name)|\(product.brand)|\(product.servingDescription)" }

    /// Saved foods have no barcode unless the database gave one, so scanning it later still works.
    func makeFoodItem() -> FoodItem {
        let item = product.makeFoodItem()
        if product.barcode.isEmpty { item.barcode = nil }
        return item
    }
}

struct OnlineSearchResult: Equatable {
    struct Failure: Equatable {
        let source: OnlineFood.Source
        let message: String
    }

    var foods: [OnlineFood] = []
    var failures: [Failure] = []
}

/// Searches USDA FoodData Central and Open Food Facts together. One source failing doesn't hide the other's results.
enum OnlineFoodSearch {
    static let enabledKey = "onlineFoodSearchEnabled"
    static let usdaKeyKey = "usdaAPIKey"
    static let minimumQueryLength = 3
    /// Below this many on-device matches, the app searches online without being asked.
    static let autoSearchBelow = 3

    /// UI tests and demos run offline-deterministic, so they never search online.
    static func isAvailable(enabled: Bool) -> Bool {
        enabled && !DemoData.shouldReset && !DemoData.shouldLoadDemo
    }

    static func search(_ rawQuery: String, usdaKey: String, session: URLSession = .shared) async -> OnlineSearchResult {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= minimumQueryLength else { return OnlineSearchResult() }
        async let usda = capture { try await FoodDataCentralClient.search(query, apiKey: usdaKey, session: session) }
        async let off = capture { try await OpenFoodFactsClient.search(query, session: session) }
        return merge(usda: await usda, openFoodFacts: await off)
    }

    private static func capture(_ work: () async throws -> [ScannedProduct]) async -> Result<[ScannedProduct], Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    /// USDA's generic foods lead; the same food from both sources is listed once.
    static func merge(usda: Result<[ScannedProduct], Error>, openFoodFacts: Result<[ScannedProduct], Error>,
                      usdaLimit: Int = 12, openFoodFactsLimit: Int = 8) -> OnlineSearchResult {
        var result = OnlineSearchResult()
        var seen = Set<String>()
        func add(_ products: [ScannedProduct], source: OnlineFood.Source, limit: Int) {
            var added = 0
            for product in products where added < limit {
                let key = "\(product.name.lowercased())|\(product.brand.lowercased())"
                guard seen.insert(key).inserted else { continue }
                result.foods.append(OnlineFood(source: source, product: product))
                added += 1
            }
        }
        switch usda {
        case .success(let products): add(products, source: .usda, limit: usdaLimit)
        case .failure(let error): result.failures.append(.init(source: .usda, message: message(for: error)))
        }
        switch openFoodFacts {
        case .success(let products): add(products, source: .openFoodFacts, limit: openFoodFactsLimit)
        case .failure(let error): result.failures.append(.init(source: .openFoodFacts, message: message(for: error)))
        }
        return result
    }

    private static func message(for error: Error) -> String {
        if let off = error as? OpenFoodFactsError {
            return off.isNetwork ? "Couldn't reach Open Food Facts." : "Open Food Facts sent something unexpected."
        }
        return (error as? LocalizedError)?.errorDescription ?? "Couldn't reach the food database."
    }
}
