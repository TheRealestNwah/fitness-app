import UIKit

/// A quick diary entry from a photo and a rough portion size, filled in properly later.
enum PhotoMeal {
    enum Portion: String, CaseIterable, Identifiable {
        case small = "Small", medium = "Medium", large = "Large"

        var id: String { rawValue }

        /// Share of a typical meal for this slot.
        var factor: Double {
            switch self {
            case .small: return 0.6
            case .medium: return 1.0
            case .large: return 1.4
            }
        }
    }

    /// A starting estimate: this meal's usual share of the daily target, scaled by portion,
    /// rounded to the nearest 10 kcal.
    static func estimate(dailyTarget: Int, meal: MealType, portion: Portion) -> Int {
        let kcal = Double(dailyTarget) * meal.budgetShare * portion.factor
        return Int((kcal / 10).rounded()) * 10
    }

    /// A JPEG no larger than `maxDimension` on its long side, to keep the store small.
    static func jpeg(from image: UIImage, maxDimension: CGFloat = 1024, quality: CGFloat = 0.7) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
