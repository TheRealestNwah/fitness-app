import XCTest
@testable import FitnessApp

final class ProductCacheTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private var cacheURL: URL!

    override func setUp() {
        cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("ProductCacheTests-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheURL)
        StubProtocol.response = nil
    }

    private func product(_ barcode: String, name: String = "Oat bar") -> ScannedProduct {
        ScannedProduct(barcode: barcode, name: name, brand: "", servingDescription: "40 g",
                       calories: 180, protein: 4, carbs: 28, fat: 6, fiber: 3)
    }

    func testLookupReportsFreshness() throws {
        var cache = ProductCache()
        cache.store(product("12345678"), now: now)
        XCTAssertEqual(cache.lookup("12345678", now: now.addingTimeInterval(86_400))?.fresh, true)
        XCTAssertEqual(cache.lookup("12345678", now: now.addingTimeInterval(40 * 86_400))?.fresh, false)
        XCTAssertNil(cache.lookup("87654321", now: now))
    }

    func testDropsLeastRecentlyUsedBeyondCapacity() {
        var cache = ProductCache()
        for i in 0..<ProductCache.capacity {
            cache.store(product(String(10_000_000 + i)), now: now.addingTimeInterval(Double(i)))
        }
        // Using the oldest keeps it; the next oldest goes instead.
        _ = cache.lookup("10000000", now: now.addingTimeInterval(1_000))
        cache.store(product("99999999"), now: now.addingTimeInterval(2_000))
        XCTAssertEqual(cache.entries.count, ProductCache.capacity)
        XCTAssertNotNil(cache.entries["10000000"])
        XCTAssertNil(cache.entries["10000001"])
        XCTAssertNotNil(cache.entries["99999999"])
    }

    func testSurvivesSaveAndLoad() {
        var cache = ProductCache()
        cache.store(product("12345678"), now: now)
        cache.save(to: cacheURL)
        XCTAssertEqual(ProductCache.load(from: cacheURL), cache)
        XCTAssertEqual(ProductCache.load(from: cacheURL.appendingPathExtension("missing")), ProductCache())
    }

    func testClientFallsBackToAStaleCacheWhenOffline() async throws {
        var cache = ProductCache()
        cache.store(product("12345678", name: "Cached bar"), now: now.addingTimeInterval(-60 * 86_400))
        cache.save(to: cacheURL)
        StubProtocol.response = .failure(URLError(.notConnectedToInternet))
        let found = try await OpenFoodFactsClient.product(barcode: "12345678", session: StubProtocol.session,
                                                          cacheURL: cacheURL, now: now)
        XCTAssertEqual(found?.name, "Cached bar")
    }

    func testClientThrowsANetworkErrorWhenOfflineAndUncached() async {
        StubProtocol.response = .failure(URLError(.notConnectedToInternet))
        do {
            _ = try await OpenFoodFactsClient.product(barcode: "12345678", session: StubProtocol.session,
                                                      cacheURL: cacheURL, now: now)
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual((error as? OpenFoodFactsError)?.isNetwork, true)
        }
    }

    func testClientCachesWhatItFinds() async throws {
        let json = #"{"status":1,"product":{"product_name":"Fresh bar","nutriments":{"energy-kcal_100g":400,"proteins_100g":10}}}"#
        StubProtocol.response = .success(Data(json.utf8))
        let found = try await OpenFoodFactsClient.product(barcode: "12345678", session: StubProtocol.session,
                                                          cacheURL: cacheURL, now: now)
        XCTAssertEqual(found?.name, "Fresh bar")
        var saved = ProductCache.load(from: cacheURL)
        XCTAssertEqual(saved.lookup("12345678", now: now)?.product.name, "Fresh bar")

        // Fresh, so the next lookup doesn't touch the network.
        StubProtocol.response = .failure(URLError(.notConnectedToInternet))
        let again = try await OpenFoodFactsClient.product(barcode: "12345678", session: StubProtocol.session,
                                                          cacheURL: cacheURL, now: now.addingTimeInterval(3_600))
        XCTAssertEqual(again?.name, "Fresh bar")
    }
}

/// Answers every request with a canned body or error.
final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var response: Result<Data, Error>?

    static var session: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: config)
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        switch Self.response {
        case .success(let data):
            let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
        }
    }

    override func stopLoading() {}
}
