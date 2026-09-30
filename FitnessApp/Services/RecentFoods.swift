import Foundation

/// Picks the foods to offer as "Log again" chips in a diary meal.
enum RecentFoods {
    struct Line: Equatable {
        /// Identifies the same food across days: the food's id when there is one, else its name.
        var key: String
        var date: Date
        var mealType: MealType
    }

    /// How far back to look.
    static let lookbackDays = 28

    /// Keys of foods eaten in `meal` before, most useful first: how many days they were eaten
    /// in that meal, then how recently. Foods already in the meal today are left out.
    static func suggestions(history: [Line], meal: MealType, alreadyLogged: Set<String>, limit: Int = 5) -> [String] {
        var days: [String: Set<Date>] = [:]
        var latest: [String: Date] = [:]
        for line in history where line.mealType == meal && !alreadyLogged.contains(line.key) {
            days[line.key, default: []].insert(Calendar.current.startOfDay(for: line.date))
            latest[line.key] = max(latest[line.key] ?? .distantPast, line.date)
        }
        return days.keys
            .sorted { a, b in
                let (da, db) = (days[a]?.count ?? 0, days[b]?.count ?? 0)
                if da != db { return da > db }
                let (la, lb) = (latest[a] ?? .distantPast, latest[b] ?? .distantPast)
                if la != lb { return la > lb }
                return a < b
            }
            .prefix(limit)
            .map { $0 }
    }
}

extension FoodLogEntry {
    /// The key `RecentFoods` groups this line by.
    var recentKey: String {
        foodItemID?.uuidString ?? foodName.trimmingCharacters(in: .whitespaces).lowercased()
    }

    var recentLine: RecentFoods.Line {
        RecentFoods.Line(key: recentKey, date: date, mealType: mealType)
    }
}
