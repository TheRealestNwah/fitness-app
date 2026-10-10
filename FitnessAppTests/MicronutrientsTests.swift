import XCTest
@testable import FitnessApp

final class MicronutrientsTests: XCTestCase {
    private func entry(_ micros: Micronutrients) -> FoodLogEntry {
        let e = FoodLogEntry(date: .now, mealType: .lunch, foodName: "Food", servings: 1, servingDescription: "1",
                             calories: 100, protein: 1, carbs: 1, fat: 1)
        e.micros = micros
        return e
    }

    func testScaledAndAdded() {
        var a = Micronutrients()
        a.calcium = 100
        a.vitaminD = 2
        let scaled = a.scaled(by: 2)
        XCTAssertEqual(scaled.calcium, 200)
        XCTAssertEqual((a + scaled).vitaminD, 6)
        XCTAssertTrue(a.hasData)
        XCTAssertFalse(Micronutrients().hasData)
    }

    func testSummaryCountsOnlyFoodsWithData() {
        var iron = Micronutrients()
        iron.iron = 4
        var more = Micronutrients()
        more.iron = 2
        let summary = MicronutrientSummary.make(entries: [entry(iron), entry(Micronutrients()), entry(more)])
        XCTAssertEqual(summary.totals.iron, 6)
        XCTAssertEqual(summary.foodsWithData, 2)
        XCTAssertEqual(summary.foodCount, 3)
        XCTAssertEqual(summary.coverageText, "Based on 2 of 3 foods")
    }

    func testWeekAverageAndProgress() {
        var m = Micronutrients()
        m.calcium = 700
        let summary = MicronutrientSummary.make(entries: [entry(m)], days: 7)
        XCTAssertEqual(summary.perDay(.calcium), 100, accuracy: 0.001)
        XCTAssertEqual(summary.progress(.calcium, reference: 1000) ?? 0, 0.1, accuracy: 0.001)
        XCTAssertNil(MicronutrientSummary.make(entries: [entry(Micronutrients())]).progress(.calcium, reference: 1000))
    }

    func testReferenceIntakesBySexAndAge() {
        XCTAssertEqual(ReferenceIntakes.amount(for: .iron, sex: .female, age: 30), 18)
        XCTAssertEqual(ReferenceIntakes.amount(for: .iron, sex: .female, age: 60), 8)
        XCTAssertEqual(ReferenceIntakes.amount(for: .iron, sex: .male, age: 30), 8)
        XCTAssertEqual(ReferenceIntakes.amount(for: .calcium, sex: .female, age: 60), 1200)
        XCTAssertEqual(ReferenceIntakes.amount(for: .vitaminD, sex: .male, age: 75), 20)
        XCTAssertEqual(ReferenceIntakes.amount(for: .vitaminC, sex: .male, age: 30), 90)
        XCTAssertEqual(ReferenceIntakes.targets(sex: .female, age: 30).count, Micronutrient.allCases.count)
    }

    func testEntryScalingAndCopy() {
        var m = Micronutrients()
        m.zinc = 4
        let e = entry(m)
        e.scale(toServings: 2)
        XCTAssertEqual(e.micros.zinc, 8)
        let copy = FoodLogEntry(date: .now, mealType: .dinner, foodName: "x", servings: 1, servingDescription: "1",
                                calories: 1, protein: 0, carbs: 0, fat: 0).withExtras(from: e, scale: 0.5)
        XCTAssertEqual(copy.micros.zinc, 4)
    }

    func testFoodDataCentralParsing() throws {
        let food: [String: Any] = [
            "description": "Spinach, raw",
            "foodNutrients": [
                ["nutrientId": 1008, "value": 23.0], ["nutrientId": 1087, "value": 99.0],
                ["nutrientId": 1089, "value": 2.7], ["nutrientId": 1114, "value": 0.0],
                ["nutrientId": 1190, "value": 194.0]
            ]
        ]
        let product = try XCTUnwrap(FoodDataCentralClient.parseFood(food))
        XCTAssertEqual(product.micros.calcium, 99, accuracy: 0.001)
        XCTAssertEqual(product.micros.iron, 2.7, accuracy: 0.001)
        XCTAssertEqual(product.micros.folate, 194, accuracy: 0.001)
        XCTAssertEqual(product.micros.vitaminD, 0)
        XCTAssertEqual(product.makeFoodItem().micros.calcium, 99, accuracy: 0.001)
    }

    func testOpenFoodFactsParsing() throws {
        let json = #"{"status":1,"product":{"product_name":"Milk","nutriments":{"energy-kcal_100g":60,"calcium_100g":0.12,"vitamin-d_100g":0.000001,"vitamin-b12_100g":0.0000005}}}"#
        let product = try XCTUnwrap(OpenFoodFactsClient.parse(Data(json.utf8), barcode: "1234567890123"))
        XCTAssertEqual(product.micros.calcium, 120, accuracy: 0.01)
        XCTAssertEqual(product.micros.vitaminD, 1, accuracy: 0.01)
        XCTAssertEqual(product.micros.vitaminB12, 0.5, accuracy: 0.01)
    }

    func testLabelParsing() {
        let label = NutritionLabelParser.parse(["Nutrition Facts", "Serving size 1 cup (240ml)", "Calories 120",
                                                "Total Fat 5g", "Total Carbohydrate 12g", "Protein 8g",
                                                "Vitamin D 5mcg 25%", "Calcium 300mg 25%", "Iron 0.1mg 2%",
                                                "Vitamin A 150 mcg 15%", "Folate 1,200 IU"])
        XCTAssertEqual(label.micros.vitaminD, 5)
        XCTAssertEqual(label.micros.calcium, 300)
        XCTAssertEqual(label.micros.iron, 0.1, accuracy: 0.001)
        XCTAssertEqual(label.micros.vitaminA, 150)
        XCTAssertEqual(NutritionLabelParser.microAmount(in: "vitamin d 10 µg", for: .vitaminD), 10)
        XCTAssertNil(NutritionLabelParser.microAmount(in: "vitamin a 500 iu", for: .vitaminA))
    }

    func testHealthValuesIncludeRecordedMicros() {
        var m = Micronutrients()
        m.calcium = 200
        m.vitaminB12 = 1.2
        let values = HealthImportRules.dietaryValues(calories: 100, protein: 1, carbs: 1, fat: 1, fiber: 0, sugar: 0,
                                                     sodiumMg: 0, micros: m)
        XCTAssertTrue(values.contains { $0.type == .dietaryCalcium && $0.value == 200 })
        XCTAssertTrue(values.contains { $0.type == .dietaryVitaminB12 && $0.value == 1.2 })
        XCTAssertFalse(values.contains { $0.type == .dietaryIron })
    }

    func testCSVRoundTrip() throws {
        var m = Micronutrients()
        m.iron = 3.5
        m.vitaminC = 60
        let e = entry(m)
        let url = try DataExporter.exportFoodLog([e])
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("calcium_mg"))
        let preview = try DataImporter.preview(csv: text)
        XCTAssertEqual(preview.food.first?.micros.iron, 3.5)
        XCTAssertEqual(preview.food.first?.micros.vitaminC, 60)
    }
}
