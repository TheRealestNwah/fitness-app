import SwiftData
import XCTest
@testable import FitnessApp

final class DataImporterTests: XCTestCase {
    func testParsesQuotedFieldsAndLineEndings() {
        let rows = DataImporter.rows("\u{FEFF}a,b\r\n\"x, y\",\"say \"\"hi\"\"\"\n\"multi\nline\",z\n\n")
        XCTAssertEqual(rows, [["a", "b"], ["x, y", "say \"hi\""], ["multi\nline", "z"]])
    }

    func testReadsStrideWeightExport() throws {
        let csv = "date,weight_kg,note\n2026-01-05T07:30:00Z,82.4,\"after run, tired\"\n2026-01-06T07:30:00Z,82.1,"
        let preview = try DataImporter.preview(csv: csv)
        XCTAssertEqual(preview.weights.map(\.kg), [82.4, 82.1])
        XCTAssertEqual(preview.weights.first?.note, "after run, tired")
        XCTAssertEqual(preview.weights.first?.date, ISO8601DateFormatter().date(from: "2026-01-05T07:30:00Z"))
        XCTAssertTrue(preview.food.isEmpty)
    }

    func testConvertsPoundsAndPlainWeightInUserUnit() throws {
        let lbs = try DataImporter.preview(csv: "Date,Weight (lbs)\n2026-01-05,180")
        XCTAssertEqual(lbs.weights.first?.kg ?? 0, 81.65, accuracy: 0.01)
        let plain = try DataImporter.preview(csv: "Date,Weight\n1/5/2026,180", plainWeightUnit: .lb)
        XCTAssertEqual(plain.weights.first?.kg ?? 0, 81.65, accuracy: 0.01)
        XCTAssertEqual(Calendar.current.component(.hour, from: plain.weights.first!.date), 7)
    }

    func testReadsStrideFoodExportRoundTrip() throws {
        let csv = """
        date,meal,food,servings,calories,protein_g,carbs_g,fat_g,fiber_g,sugar_g,sodium_mg
        2026-01-05T12:15:00Z,lunch,"Soup, tomato",1.5,240.0,6.0,30.0,9.0,4.0,12.0,800.0
        """
        let food = try DataImporter.preview(csv: csv).food
        XCTAssertEqual(food, [DataImporter.Food(date: ISO8601DateFormatter().date(from: "2026-01-05T12:15:00Z")!,
                                                meal: .lunch, name: "Soup, tomato", servings: 1.5, calories: 240,
                                                protein: 6, carbs: 30, fat: 9, fiber: 4, sugar: 12, sodiumMg: 800)])
    }

    func testReadsExtraNutrientsFromStrideExport() throws {
        let csv = """
        date,meal,food,servings,calories,protein_g,carbs_g,fat_g,fiber_g,sugar_g,sodium_mg,saturated_fat_g,potassium_mg,cholesterol_mg
        2026-01-05T12:15:00Z,lunch,Omelette,1.0,300.0,20.0,2.0,22.0,0.0,1.0,400.0,7.5,250.0,370.0
        """
        let food = try XCTUnwrap(DataImporter.preview(csv: csv).food.first)
        XCTAssertEqual(food.saturatedFat, 7.5)
        XCTAssertEqual(food.potassiumMg, 250)
        XCTAssertEqual(food.cholesterolMg, 370)
    }

    func testReadsMyFitnessPalStyleMealTotals() throws {
        let csv = """
        Date,Meal,Calories,Fat (g),Saturated Fat,Sodium (mg),Carbohydrates (g),Fiber,Sugar,Protein (g),Note
        2026-01-05,Breakfast,"1,050",12,4,300,40,5,10,20,
        2026-01-05,Snacks,150,1,0,50,30,1,20,2,
        """
        let food = try DataImporter.preview(csv: csv).food
        XCTAssertEqual(food.map(\.meal), [.breakfast, .snack])
        XCTAssertEqual(food.map(\.name), ["Breakfast (imported)", "Snack (imported)"])
        XCTAssertEqual(food.first?.calories, 1050)
        XCTAssertEqual(food.first?.fat, 12)
        XCTAssertEqual(food.first?.sodiumMg, 300)
        XCTAssertEqual(food.first?.carbs, 40)
        XCTAssertEqual(food.first?.protein, 20)
        XCTAssertEqual(Calendar.current.component(.hour, from: food[0].date), 8)
    }

    func testReadsLoseItFoodLog() throws {
        let csv = """
        Date,Name,Icon,Type,Quantity,Units,Calories,Deleted,Fat (g),Protein (g),Carbohydrates (g),Saturated Fat (g),Sugars (g),Fiber (g),Cholesterol (mg),Sodium (mg)
        01/05/2026,Oatmeal,Oatmeal,Breakfast,1,Cup,166,false,3.6,5.9,28,0.6,0.6,4,0,9
        01/05/2026,Cookie,Cookie,Snacks,2,Each,160,true,8,2,20,4,12,1,10,110
        01/05/2026,Chicken Breast,Chicken,Dinner,1.5,Serving,248,false,5.4,46.5,0,1.5,0,0,128,111
        """
        let food = try DataImporter.preview(csv: csv).food
        XCTAssertEqual(food.map(\.name), ["Oatmeal", "Chicken Breast"])
        XCTAssertEqual(food.map(\.meal), [.breakfast, .dinner])
        XCTAssertEqual(food.first?.sugar, 0.6)
        XCTAssertEqual(food.first?.saturatedFat, 0.6)
        XCTAssertEqual(food.last?.servings, 1.5)
        XCTAssertEqual(food.last?.protein, 46.5)
        XCTAssertEqual(food.last?.cholesterolMg, 128)
        XCTAssertEqual(Calendar.current.component(.hour, from: food[1].date), 19)
    }

    func testSkipsUnreadableRows() throws {
        let preview = try DataImporter.preview(csv: "date,weight_kg\nyesterday,80\n2026-01-05,abc\n2026-01-05,5\n2026-01-06,80")
        XCTAssertEqual(preview.weights.count, 1)
        XCTAssertEqual(preview.skipped, 3)
    }

    func testRejectsUnrecognisedFiles() {
        XCTAssertThrowsError(try DataImporter.preview(csv: "name,score\nA,1"))
        XCTAssertThrowsError(try DataImporter.preview(csv: "calories\n100"))
        XCTAssertThrowsError(try DataImporter.preview(csv: ""))
    }

    @MainActor
    func testApplySkipsWhatIsAlreadyThere() throws {
        let container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let csv = "date,weight_kg\n2026-01-05T07:00:00Z,82.4\n2026-01-06T07:00:00Z,82.0"
        let first = DataImporter.withoutDuplicates(try DataImporter.preview(csv: csv), context: context)
        XCTAssertEqual(first.weights.count, 2)
        try DataImporter.apply(first, context: context)
        let again = DataImporter.withoutDuplicates(try DataImporter.preview(csv: csv), context: context)
        XCTAssertTrue(again.isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WeightEntry>()), 2)
    }
}
