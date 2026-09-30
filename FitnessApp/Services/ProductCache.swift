import Foundation

/// Barcode lookups remembered on device, so a product looked up once still works without signal
/// (a supermarket basement). Bounded: the least recently used products are dropped first.
struct ProductCache: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var product: ScannedProduct
        var fetched: Date
        var lastUsed: Date
    }

    static let capacity = 300
    /// Younger than this, the cached product is used without asking the network.
    static let freshDays = 30

    private(set) var entries: [String: Entry] = [:]

    /// The cached product and whether it's still fresh; marks it as used.
    mutating func lookup(_ barcode: String, now: Date = .now) -> (product: ScannedProduct, fresh: Bool)? {
        guard var entry = entries[barcode] else { return nil }
        entry.lastUsed = now
        entries[barcode] = entry
        let fresh = now.timeIntervalSince(entry.fetched) < Double(Self.freshDays) * 86_400
        return (entry.product, fresh)
    }

    mutating func store(_ product: ScannedProduct, now: Date = .now) {
        entries[product.barcode] = Entry(product: product, fetched: now, lastUsed: now)
        guard entries.count > Self.capacity else { return }
        let oldest = entries.sorted { $0.value.lastUsed < $1.value.lastUsed }.prefix(entries.count - Self.capacity)
        for (barcode, _) in oldest { entries[barcode] = nil }
    }
}

extension ProductCache {
    /// Kept in Caches: the system may clear it under storage pressure, which only costs a lookup.
    static var fileURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenFoodFactsProducts.json")
    }

    static func load(from url: URL = fileURL) -> ProductCache {
        guard let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(ProductCache.self, from: data) else { return ProductCache() }
        return cache
    }

    func save(to url: URL = Self.fileURL) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
