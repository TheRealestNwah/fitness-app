import Foundation

/// Where the 7-day trend sits relative to the maintenance band.
enum MaintenanceStatus: Equatable {
    case inBand
    /// Above the band's upper edge by this much.
    case above(Double)
    /// Below the band's lower edge by this much.
    case below(Double)

    var isOutside: Bool { self != .inBand }
}

enum MaintenanceCalculator {
    static let defaultBandKg = 1.5
    static let bandRange: ClosedRange<Double> = 0.5...3.0

    static func status(trendKg: Double, centerKg: Double, bandKg: Double) -> MaintenanceStatus {
        let band = abs(bandKg)
        if trendKg > centerKg + band { return .above(trendKg - (centerKg + band)) }
        if trendKg < centerKg - band { return .below((centerKg - band) - trendKg) }
        return .inBand
    }

    /// Where the trend sits across the band, 0 at the lower edge and 1 at the upper, clamped.
    static func position(trendKg: Double, centerKg: Double, bandKg: Double) -> Double {
        let band = max(abs(bandKg), 0.01)
        return min(max((trendKg - (centerKg - band)) / (2 * band), 0), 1)
    }

    /// Offer maintenance once the trend (not one light morning) has reached the goal.
    static func shouldOffer(trendKg: Double?, goalKg: Double, isMaintaining: Bool) -> Bool {
        guard !isMaintaining, let trendKg else { return false }
        return trendKg <= goalKg
    }

    /// Calories to hold weight: maintenance with no planned loss, still above the safety floor.
    static func calorieTarget(tdee: Double, sex: BiologicalSex) -> Int {
        NutritionCalculator.dailyCalorieTarget(tdee: tdee, weeklyLossKg: 0, sex: sex)
    }
}
