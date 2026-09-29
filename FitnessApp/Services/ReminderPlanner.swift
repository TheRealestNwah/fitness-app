import Foundation

/// Works out which one-off reminders to schedule for the next few days, so today's can
/// adapt to what has already been logged: no water nudges once the goal is met, no
/// reminder for a meal already logged, a nudge if nothing is logged by lunchtime, and an
/// optional evening check-in when dinner still isn't logged.
enum ReminderPlanner {
    struct Settings {
        var waterEnabled: Bool
        var waterGoalMl: Double
        var mealsEnabled: Bool
        /// Hour of the evening check-in; nil when it's off.
        var dayCloseHour: Int? = nil
        /// Hour of the protein check; nil when it's off.
        var proteinHour: Int? = nil
    }

    struct Today {
        var waterMl: Double
        var loggedMeals: Set<MealType>
        /// Grams still needed to reach today's protein target.
        var proteinShortG: Double = 0
        /// A saved food that would close most of the gap, if one fits.
        var proteinIdea: String? = nil
    }

    /// Below this, a protein nudge isn't worth sending.
    static let proteinNudgeMinimumG = 15.0

    /// The saved food with the most protein per calorie that fits in what's left, among ones
    /// with a useful amount (at least a third of the gap or 10 g).
    static func proteinIdea(foods: [(name: String, protein: Double, kcal: Double)], shortG: Double,
                            kcalLeft: Double) -> String? {
        foods.filter { $0.kcal > 0 && $0.kcal <= max(kcalLeft, 0) && $0.protein >= min(shortG / 3, 10) }
            .max { $0.protein / $0.kcal < $1.protein / $1.kcal }?
            .name
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
                                              title: String(localized: "Time for a glass of water"),
                                              body: String(localized: "A quick sip now keeps hunger and headaches away.")))
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
                        title: nothingYet ? String(localized: "Nothing logged yet today") : String(localized: "Log your \(slot.meal.inSentence)"),
                        body: nothingYet ? String(localized: "A quick log of breakfast and lunch keeps today's numbers useful.")
                                         : String(localized: "Logging right after you eat keeps your calorie count honest.")))
                }
            }

            if let hour = settings.dayCloseHour,
               let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), date > now,
               !(isToday && today.loggedMeals.contains(.dinner)),
               // A dinner reminder in the hour before would say the same thing.
               !reminders.contains(where: { $0.id == "meal.\(key).dinner" && date.timeIntervalSince($0.date) <= 3600 }) {
                let nothing = isToday && today.loggedMeals.isEmpty
                reminders.append(Reminder(
                    id: "dayclose.\(key)", date: date,
                    title: String(localized: "Finish today's log"),
                    body: nothing ? String(localized: "Nothing's logged today yet. A rough entry for each meal still keeps your week on track.")
                                  : String(localized: "Dinner isn't logged yet. A quick entry keeps today's numbers right.")))
            }
        }
        // Protein is only known for today; later days are planned when the app is next opened.
        if let hour = settings.proteinHour, today.proteinShortG >= proteinNudgeMinimumG,
           let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: start), date > now {
            let short = Int(today.proteinShortG.rounded())
            reminders.append(Reminder(
                id: "protein.\(dayKey(start, calendar: calendar))", date: date,
                title: String(localized: "Protein check"),
                body: today.proteinIdea.map { String(localized: "You're \(short) g short of today's protein goal. \($0) would close a good part of it.") }
                    ?? String(localized: "You're \(short) g short of today's protein goal. A protein-rich dinner or snack would close it.")))
        }
        return reminders
    }

    private static func dayKey(_ day: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
