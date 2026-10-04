#if os(iOS)
import XCTest
import UIKit
@testable import FitnessApp

final class PhotoMealTests: XCTestCase {
    func testEstimateFollowsTheMealsShareAndPortion() {
        // Lunch is 35% of 2000 = 700 kcal for a medium portion.
        XCTAssertEqual(PhotoMeal.estimate(dailyTarget: 2000, meal: .lunch, portion: .medium), 700)
        XCTAssertEqual(PhotoMeal.estimate(dailyTarget: 2000, meal: .lunch, portion: .small), 420)
        XCTAssertEqual(PhotoMeal.estimate(dailyTarget: 2000, meal: .snack, portion: .large), 280)
    }

    func testPhotosAreShrunkBeforeStoring() throws {
        let big = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 2000)).image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 3000, height: 2000))
        }
        let data = try XCTUnwrap(PhotoMeal.jpeg(from: big))
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(max(decoded.size.width * decoded.scale, decoded.size.height * decoded.scale), 1024, accuracy: 1)
    }

    func testNewFavouriteStartsWithTheFirstDiaryPhoto() {
        func entry(_ name: String, photo: Data?) -> FoodLogEntry {
            let e = FoodLogEntry(date: .now, mealType: .lunch, foodName: name, servings: 1, servingDescription: "serving",
                                 calories: 100, protein: 0, carbs: 0, fat: 0)
            e.photo = photo
            return e
        }
        let plain = entry("Soup", photo: nil)
        let first = entry("Salad", photo: Data([1]))
        let second = entry("Bread", photo: Data([2]))
        XCTAssertEqual(SavedMeal.firstPhoto(in: [plain, first, second]), Data([1]))
        XCTAssertNil(SavedMeal.firstPhoto(in: [plain]))
    }
}
#endif
