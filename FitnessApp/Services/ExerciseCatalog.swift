import Foundation

enum ExerciseSettings {
    /// Share of logged exercise calories added back to today's budget: 0, 50 or 100.
    static let earnBackPercentKey = "exerciseEarnBackPercent"

    static var earnBackPercent: Int { UserDefaults.standard.integer(forKey: earnBackPercentKey) }
}

/// A small activity list with MET values (Compendium of Physical Activities, rounded).
enum ExerciseCatalog {
    struct Activity: Identifiable, Hashable {
        var name: String
        var met: Double
        var systemImage: String
        var id: String { name }
    }

    static let activities: [Activity] = [
        Activity(name: "Walking, moderate", met: 3.5, systemImage: "figure.walk"),
        Activity(name: "Walking, brisk", met: 4.3, systemImage: "figure.walk"),
        Activity(name: "Hiking", met: 6.0, systemImage: "figure.hiking"),
        Activity(name: "Running, easy", met: 8.0, systemImage: "figure.run"),
        Activity(name: "Running, fast", met: 11.0, systemImage: "figure.run"),
        Activity(name: "Cycling, leisurely", met: 4.0, systemImage: "figure.outdoor.cycle"),
        Activity(name: "Cycling, moderate", met: 8.0, systemImage: "figure.outdoor.cycle"),
        Activity(name: "Swimming", met: 6.0, systemImage: "figure.pool.swim"),
        Activity(name: "Strength training", met: 5.0, systemImage: "figure.strengthtraining.traditional"),
        Activity(name: "HIIT", met: 8.0, systemImage: "figure.highintensity.intervaltraining"),
        Activity(name: "Yoga", met: 2.5, systemImage: "figure.yoga"),
        Activity(name: "Pilates", met: 3.0, systemImage: "figure.pilates"),
        Activity(name: "Dancing", met: 5.0, systemImage: "figure.dance"),
        Activity(name: "Rowing machine", met: 7.0, systemImage: "figure.rower"),
        Activity(name: "Elliptical", met: 5.0, systemImage: "figure.elliptical"),
        Activity(name: "Stair climbing", met: 8.8, systemImage: "figure.stairs"),
        Activity(name: "Tennis", met: 7.3, systemImage: "figure.tennis"),
        Activity(name: "Football", met: 7.0, systemImage: "figure.soccer"),
        Activity(name: "Gardening", met: 3.8, systemImage: "leaf"),
        Activity(name: "Housework", met: 3.3, systemImage: "house"),
    ]

    /// Calories above resting: (MET − 1) × kg × hours, so a workout doesn't also count the
    /// resting burn the daily target already includes.
    static func netCalories(met: Double, weightKg: Double, minutes: Double) -> Double {
        max(met - 1, 0) * weightKg * minutes / 60
    }

    static func earnBack(exerciseKcal: Double, percent: Int) -> Int {
        guard percent > 0, exerciseKcal > 0 else { return 0 }
        return Int((exerciseKcal * Double(percent) / 100).rounded())
    }

    /// Apple Health's active energy already includes logged workouts, so the two credits
    /// overlap; take the larger rather than adding them.
    static func combinedCredit(health: Int, exercise: Int) -> Int {
        max(health, exercise)
    }
}
