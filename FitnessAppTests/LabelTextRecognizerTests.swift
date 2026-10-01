import UIKit
import XCTest
@testable import FitnessApp

@MainActor
final class LabelTextRecognizerTests: XCTestCase {
    func testRecipePhotoReadsWordsAndQuantitiesWithSpellingCorrection() async throws {
        let image = photo(lines: ["Lemon Chicken", "Serves 4", "Ingredients", "1 onion", "2 lemons",
                                  "Method", "1. Chop the onion and slice the lemons."])
        let lines = await LabelTextRecognizer.lines(in: image, correctingSpelling: true)
        let recipe = try XCTUnwrap(RecipeTextParser.parse(lines: lines))
        XCTAssertEqual(recipe.name, "Lemon Chicken")
        XCTAssertEqual(recipe.servings, 4)
        XCTAssertEqual(recipe.ingredients, ["1 onion", "2 lemons"])
        XCTAssertTrue(recipe.instructions.contains("Chop the onion"))
    }

    func testNutritionPhotoStillPreservesDecimalValues() async {
        let image = photo(lines: ["Nutrition Facts", "Calories 230", "Total Fat 8.5g", "Protein 3g"])
        let lines = await LabelTextRecognizer.lines(in: image)
        let label = NutritionLabelParser.parse(lines)
        XCTAssertEqual(label.calories, 230)
        XCTAssertEqual(label.fat, 8.5)
        XCTAssertEqual(label.protein, 3)
    }

    private func photo(lines: [String]) -> UIImage {
        let size = CGSize(width: 1100, height: 80 + lines.count * 70)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(at: CGPoint(x: 40, y: 40 + index * 70), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 36),
                    .foregroundColor: UIColor.black,
                ])
            }
        }
    }
}
