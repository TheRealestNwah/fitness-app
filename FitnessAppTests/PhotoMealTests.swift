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
}
