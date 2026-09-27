import Foundation
import SwiftData

/// A logged workout, entered by hand or imported from Apple Health.
@Model
final class ExerciseEntry {
    var uuid: UUID = UUID()
    var date: Date = Date()
    var activity: String = ""
    var minutes: Double = 0
    /// Calories burned above resting, which is what earn-back credits.
    var calories: Double = 0
    /// Apple Health workout id when imported.
    var sourceID: String?

    init(date: Date = .now, activity: String, minutes: Double, calories: Double) {
        self.uuid = UUID()
        self.date = date
        self.activity = activity
        self.minutes = minutes
        self.calories = calories
    }
}
