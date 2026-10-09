import XCTest
@testable import FitnessApp

final class OnlineFoodSearchTests: XCTestCase {
    override func tearDown() {
        StubProtocol.response = nil
    }

    private func json(_ object: Any) -> Data {
        // swiftlint:disable:next force_try
        try! JSONSerialization.data(withJSONObject: object)
    }

    private func nutrient(_ id: Int, _ value: Double) -> [String: Any] {
        ["nutrientId": id, "value": value]
    }

    // MARK: USDA

    func testGenericFoodIsPer100GramsAndListedBeforeBranded() throws {
        let data = json(["foods": [
            ["fdcId": 1, "description": "PROTEIN BAR", "dataType": "Branded", "brandName": "ACME",
             "servingSize": 50.0, "servingSizeUnit": "g", "householdServingFullText": "1 bar",
             "foodNutrients": [nutrient(1008, 400), nutrient(1003, 20), nutrient(1093, 300)]],
            ["fdcId": 2, "description": "Chicken, thigh, roasted", "dataType": "SR Legacy",
             "foodNutrients": [nutrient(1008, 209), nutrient(1003, 26), nutrient(1004, 11), nutrient(1005, 0),
                               nutrient(1253, 130), nutrient(1092, 240)]]
        ]])
        let found = try FoodDataCentralClient.parse(data)
        XCTAssertEqual(found.map(\.name), ["Chicken, thigh, roasted", "Protein Bar"])
        XCTAssertEqual(found[0].servingDescription, "100 g")
        XCTAssertEqual(found[0].calories, 209, accuracy: 0.01)
        XCTAssertEqual(found[0].cholesterol, 130, accuracy: 0.01)
        XCTAssertEqual(found[0].potassium, 240, accuracy: 0.01)
    }

    func testBrandedFoodIsScaledToItsLabelServing() throws {
        let data = json(["foods": [
            ["fdcId": 1, "description": "PROTEIN BAR", "dataType": "Branded", "brandName": "ACME",
             "gtinUpc": "012345678905", "servingSize": 50.0, "servingSizeUnit": "GRM",
             "householdServingFullText": "1 BAR",
             "foodNutrients": [nutrient(1008, 400), nutrient(1003, 20), nutrient(1093, 300)]]
        ]])
        let bar = try XCTUnwrap(FoodDataCentralClient.parse(data).first)
        XCTAssertEqual(bar.servingDescription, "1 bar (50 g)")
        XCTAssertEqual(bar.calories, 200, accuracy: 0.01)
        XCTAssertEqual(bar.protein, 10, accuracy: 0.01)
        XCTAssertEqual(bar.sodium, 150, accuracy: 0.01)
        XCTAssertEqual(bar.brand, "Acme")
        XCTAssertEqual(bar.barcode, "012345678905")
    }

    func testEnergyFallsBackToAtwaterThenKilojoules() throws {
        let atwater = json(["foods": [["fdcId": 1, "description": "Oats", "dataType": "Foundation",
                                       "foodNutrients": [nutrient(2047, 380)]]]])
        XCTAssertEqual(try FoodDataCentralClient.parse(atwater).first?.calories ?? 0, 380, accuracy: 0.01)
        let kilojoules = json(["foods": [["fdcId": 1, "description": "Oats", "dataType": "Foundation",
                                          "foodNutrients": [nutrient(1062, 1673.6)]]]])
        XCTAssertEqual(try FoodDataCentralClient.parse(kilojoules).first?.calories ?? 0, 400, accuracy: 0.1)
        let none = json(["foods": [["fdcId": 1, "description": "Water", "foodNutrients": []]]])
        XCTAssertTrue(try FoodDataCentralClient.parse(none).isEmpty)
    }

    func testUnexpectedUSDAResponseThrows() {
        XCTAssertThrowsError(try FoodDataCentralClient.parse(Data("nope".utf8)))
    }

    func testUSDASearchURLUsesTheDemoKeyWhenNoneIsSet() {
        let url = FoodDataCentralClient.searchURL(for: "rice", apiKey: "", limit: 5).absoluteString
        XCTAssertTrue(url.contains("api_key=DEMO_KEY"))
        XCTAssertTrue(url.contains("query=rice"))
        XCTAssertTrue(FoodDataCentralClient.searchURL(for: "rice", apiKey: "abc", limit: 5).absoluteString.contains("api_key=abc"))
    }

    // MARK: Open Food Facts

    func testOpenFoodFactsSearchKeepsUsableProducts() throws {
        let data = json(["products": [
            ["code": "3017620422003", "product_name": "Hazelnut spread", "brands": "Nutella, Ferrero",
             "serving_size": "15 g", "serving_quantity": 15,
             "nutriments": ["energy-kcal_100g": 539, "proteins_100g": 6.3, "carbohydrates_100g": 57.5, "fat_100g": 30.9]],
            ["code": "111", "product_name": "Bad barcode", "nutriments": ["energy-kcal_100g": 100]],
            ["code": "22222222", "product_name": "", "nutriments": ["energy-kcal_100g": 100]],
            ["code": "33333333", "product_name": "No energy", "nutriments": [:]]
        ]])
        let found = try OpenFoodFactsClient.parseSearch(data)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].name, "Hazelnut spread")
        XCTAssertEqual(found[0].brand, "Nutella")
        XCTAssertEqual(found[0].calories, 80.85, accuracy: 0.01)
        XCTAssertThrowsError(try OpenFoodFactsClient.parseSearch(Data("[]".utf8)))
    }

    // MARK: Combined

    private func product(_ name: String, brand: String = "") -> ScannedProduct {
        ScannedProduct(barcode: "", name: name, brand: brand, servingDescription: "100 g",
                       calories: 100, protein: 1, carbs: 1, fat: 1, fiber: 0)
    }

    func testMergeListsUSDAFirstAndDropsDuplicates() {
        let result = OnlineFoodSearch.merge(
            usda: .success([product("Rice"), product("Rice, brown")]),
            openFoodFacts: .success([product("rice"), product("Rice cakes", brand: "Acme")]))
        XCTAssertEqual(result.foods.map(\.product.name), ["Rice", "Rice, brown", "Rice cakes"])
        XCTAssertEqual(result.foods.map(\.source), [.usda, .usda, .openFoodFacts])
        XCTAssertTrue(result.failures.isEmpty)
    }

    func testMergeKeepsResultsWhenOneSourceFails() {
        let result = OnlineFoodSearch.merge(usda: .failure(FoodDataCentralError.rateLimited),
                                            openFoodFacts: .success([product("Rice cakes")]))
        XCTAssertEqual(result.foods.map(\.product.name), ["Rice cakes"])
        XCTAssertEqual(result.failures.map(\.source), [.usda])
    }

    func testMergeRespectsPerSourceLimits() {
        let many = (0..<30).map { product("Food \($0)") }
        let result = OnlineFoodSearch.merge(usda: .success(many), openFoodFacts: .success([]), usdaLimit: 5)
        XCTAssertEqual(result.foods.count, 5)
    }

    func testShortQueriesDoNotHitTheNetwork() async {
        StubProtocol.response = .failure(URLError(.notConnectedToInternet))
        let result = await OnlineFoodSearch.search("ab", usdaKey: "", session: StubProtocol.session)
        XCTAssertEqual(result, OnlineSearchResult())
    }

    func testOfflineReportsBothSourcesFailing() async {
        StubProtocol.response = .failure(URLError(.notConnectedToInternet))
        let result = await OnlineFoodSearch.search("rice", usdaKey: "", session: StubProtocol.session)
        XCTAssertTrue(result.foods.isEmpty)
        XCTAssertEqual(Set(result.failures.map(\.source)), [.usda, .openFoodFacts])
    }

    func testSavedFoodHasNoBarcodeUnlessTheDatabaseGaveOne() {
        XCTAssertNil(OnlineFood(source: .usda, product: product("Rice")).makeFoodItem().barcode)
        var scanned = product("Bar")
        scanned.barcode = "012345678905"
        XCTAssertEqual(OnlineFood(source: .openFoodFacts, product: scanned).makeFoodItem().barcode, "012345678905")
    }
}
