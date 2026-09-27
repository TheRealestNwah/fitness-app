import Foundation

/// Works out which one-off reminders to schedule for the next few days, so today's can
/// adapt to what has already been logged: no water nudges once the goal is met, no
/// reminder for a meal already logged, and a nudge if nothing is logged by lunchtime.
enum ReminderPlanner {
    struct Settings {
        var waterEnabled: Bool
        var waterGoalMl: Double
        var mealsEnabled: Bool
    }

    struct Today {
        var waterMl: Double
        var loggedMeals: Set<MealType>
    }

    struct Reminder: Equatable {
        var id: String
        var date: Date
        var title: String
        var body: String
    }

    static let waterHours = Array(stride(from: 9, through: 21, by: 2))
    static let mealTimes: [(meal: MealType, hour: Int, minute: Int)] = [(.breakfast, 8, 30), (.lunch, 13, 30), (.dinner, 19, 30)]
    /// Scheduled ahead so reminders still arrive on days the app isn't opened.
    /// iOS keeps at most 64 pending requests; this plans at most 40.
    static let daysAhead = 4

    static func plan(settings: Settings, today: Today, now: Date = .now,
                     calendar: Calendar = .current) -> [Reminder] {
        var reminders: [Reminder] = []
        let start = calendar.startOfDay(for: now)
        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let isToday = offset == 0
            let key = dayKey(day, calendar: calendar)

            if settings.waterEnabled, !(isToday && today.waterMl >= settings.waterGoalMl) {
                for hour in waterHours {
                    guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), date > now else { continue }
                    reminders.append(Reminder(id: "water.\(key).\(hour)", date: date,
                                              title: "Time for a glass of water",
                                              body: "A quick sip now keeps hunger and headaches away."))
                }
            }

            if settings.mealsEnabled {
                for slot in mealTimes {
                    guard let date = calendar.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: day),
                          date > now else { continue }
                    if isToday, today.loggedMeals.contains(slot.meal) { continue }
                    let nothingYet = isToday && slot.meal == .lunch && today.loggedMeals.isEmpty
                    reminders.append(Reminder(
                        id: "meal.\(key).\(slot.meal.rawValue)", date: date,
                        title: nothingYet ? "Nothing logged yet today" : "Log your \(slot.meal.label.lowercased())",
                        body: nothingYet ? "A quick log of breakfast and lunch keeps today's numbers useful."
                                         : "Logging right after you eat keeps your calorie count honest."))
                }
            }
        }
        return reminders
    }

    private static func dayKey(_ day: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
