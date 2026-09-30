import SwiftData
import XCTest
@testable import FitnessApp

final class DrinkNutrientsTests: XCTestCase {
    func testStandardDrinks() {
        XCTAssertEqual(Alcohol.standardDrinks(grams: 28), 2)
        XCTAssertEqual(Alcohol.standardDrinks(grams: -3), 0)
    }

    func testGramsFromABV() {
        // A 12 oz (355 ml) beer at 5% has about 14 g of alcohol: one standard drink.
        XCTAssertEqual(Alcohol.grams(percentABV: 5, millilitres: 355), 14, accuracy: 0.1)
    }

    func testSeededDrinksAddUp() {
        for drink in SeedData.drinks {
            let macros = drink.protein * 4 + drink.carbs * 4 + drink.fat * 9 + drink.alcohol * Alcohol.kcalPerGram
            XCTAssertEqual(drink.calories, macros, accuracy: max(drink.calories * 0.15, 5), drink.name)
        }
        XCTAssertTrue(SeedData.drinks.contains { $0.alcohol > 0 })
        XCTAssertTrue(SeedData.drinks.contains { $0.caffeine > 0 })
    }

    func testEntriesCarryAndScaleAlcoholAndCaffeine() {
        let beer = FoodItem(name: "Beer", servingDescription: "12 fl oz", calories: 153, protein: 1.6, carbs: 13, fat: 0)
        beer.alcohol = 14
        let entry = FoodLogEntry(date: .now, mealType: .dinner, foodName: "Beer", servings: 2, servingDescription: "12 fl oz",
                                 calories: 306, protein: 3.2, carbs: 26, fat: 0)
            .withExtras(from: beer, servings: 2)
        XCTAssertEqual(entry.alcohol, 28)
        entry.scale(toServings: 1)
        XCTAssertEqual(entry.alcohol, 14)
        let copy = entry.copy(to: .snack, on: .now)
        XCTAssertEqual(copy.alcohol, 14)
        let saved = SavedMealItem(entry: entry)
        XCTAssertEqual(saved.alcohol, 14)
    }

    func testReadsAlcoholAndCaffeineFromStrideExport() throws {
        let csv = """
        date,meal,food,servings,calories,protein_g,carbs_g,fat_g,fiber_g,sugar_g,sodium_mg,saturated_fat_g,potassium_mg,cholesterol_mg,alcohol_g,caffeine_mg
        2026-01-05T19:15:00Z,dinner,Beer,1.0,153.0,1.6,13.0,0.0,0.0,0.0,14.0,0.0,96.0,0.0,14.0,0.0
        2026-01-05T08:15:00Z,breakfast,Coffee,1.0,2.0,0.3,0.0,0.0,0.0,0.0,5.0,0.0,116.0,0.0,0.0,95.0
        """
        let food = try DataImporter.preview(csv: csv).food
        XCTAssertEqual(food.map(\.alcoholG), [14, 0])
        XCTAssertEqual(food.map(\.caffeineMg), [0, 95])
    }

    func testOpenFoodFactsAlcoholIsConvertedFromABV() throws {
        let json = #"{"status":1,"product":{"product_name":"Lager","nutriments":{"energy-kcal_100g":43,"alcohol_100g":5,"caffeine_100g":0}}}"#
        let product = try XCTUnwrap(OpenFoodFactsClient.parse(Data(json.utf8), barcode: "12345678"))
        XCTAssertEqual(product.alcohol, 3.9, accuracy: 0.05)
        XCTAssertEqual(product.makeFoodItem().alcohol, product.alcohol)
    }

    @MainActor
    func testExistingInstallGetsDrinkValuesOnce() throws {
        let suite = "DrinkNutrientsTests"
        UserDefaults().removePersistentDomain(forName: suite)
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(SeedData.restaurantFoodsVersion, forKey: SeedData.restaurantFoodsVersionKey)

        let container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        // An install from before drinks had caffeine.
        let coffee = FoodItem(name: SeedData.drinks[0].name, servingDescription: "1 cup (240 ml)",
                              calories: 2, protein: 0.3, carbs: 0, fat: 0)
        context.insert(coffee)
        try context.save()

        SeedData.seedIfNeeded(context: context, defaults: defaults)
        XCTAssertEqual(coffee.caffeine, SeedData.drinks[0].caffeine)
        let all = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(all.count, SeedData.drinks.count)
        XCTAssertEqual(defaults.integer(forKey: SeedData.drinksVersionKey), SeedData.drinksVersion)
    }
}
