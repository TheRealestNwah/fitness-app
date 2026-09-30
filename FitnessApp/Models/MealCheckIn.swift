import Foundation
import SwiftData

/// How hungry someone was before a meal and how they felt after, one per meal per day.
@Model
final class MealCheckIn {
    var uuid: UUID = UUID()
    /// Start of the day the meal belongs to.
    var day: Date = Date()
    var mealTypeRaw: String = MealType.snack.rawValue
    /// 1 (not hungry) to 5 (very hungry), before eating.
    var hunger: Int?
    /// 1 (low) to 5 (great), after eating.
    var mood: Int?

    init(day: Date, mealType: MealType, hunger: Int? = nil, mood: Int? = nil) {
        self.uuid = UUID()
        self.day = Calendar.current.startOfDay(for: day)
        self.mealTypeRaw = mealType.rawValue
        self.hunger = hunger
        self.mood = mood
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }
}

enum MealRating {
    static let range = 1...5

    static func hungerLabel(_ value: Int) -> String {
        switch value {
        case 1: String(localized: "Not hungry")
        case 2: String(localized: "A little hungry")
        case 3: String(localized: "Hungry")
        case 4: String(localized: "Very hungry")
        default: String(localized: "Starving")
        }
    }

    static func moodLabel(_ value: Int) -> String {
        switch value {
        case 1: String(localized: "Low")
        case 2: String(localized: "Meh")
        case 3: String(localized: "Okay")
        case 4: String(localized: "Good")
        default: String(localized: "Great")
        }
    }
}
