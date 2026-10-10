import Foundation

/// Works out which one-off reminders to schedule for the next few days, so today's can
/// adapt to what has already been logged: no weigh-in reminder once today's weight is in,
/// no water nudges once the goal is met, no reminder for a meal already logged, a nudge if
/// nothing is logged by lunchtime, and an optional evening check-in when dinner still isn't
/// logged. Weigh-in, meal, check-in and protein reminders can pause during a diet break.
enum ReminderPlanner {
    struct Settings {
        var waterEnabled: Bool
        var waterGoalMl: Double
        var mealsEnabled: Bool
        /// Hour of the evening check-in; nil when it's off.
        var dayCloseHour: Int? = nil
        /// Hour of the protein check; nil when it's off.
        var proteinHour: Int? = nil
        /// Hour of the morning weigh-in reminder; nil when it's off.
        var weighInHour: Int? = nil
        /// Days when weigh-in, meal, check-in and protein reminders are paused (a diet break);
        /// the end day is not included.
        var pause: DateInterval? = nil
        /// The day the next medication dose is due, and the hour to remind; nil when off.
        /// Not paused by a diet break.
        var medicationDue: Date? = nil
        var medicationHour: Int? = nil
        var medicationName = ""
        /// Hide numbers mode: no protein check, and no wording about calories.
        var hideNumbers = false
    }

    struct Today {
        var waterMl: Double
        var loggedMeals: Set<MealType>
        /// Grams still needed to reach today's protein target.
        var proteinShortG: Double = 0
        /// A saved food that would close most of the gap, if one fits.
        var proteinIdea: String? = nil
        var weighedIn = false
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
    /// iOS keeps at most 64 pending requests; this plans at most 50.
    static let daysAhead = 4

    static func plan(settings: Settings, today: Today, now: Date = .now,
                     calendar: Calendar = .current) -> [Reminder] {
        var reminders: [Reminder] = []
        let start = calendar.startOfDay(for: now)
        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let isToday = offset == 0
            let key = dayKey(day, calendar: calendar)
            let paused = isPaused(day, settings.pause, calendar: calendar)

            // Due that day, or overdue (reminded today only).
            if let due = settings.medicationDue, let hour = settings.medicationHour,
               calendar.isDate(day, inSameDayAs: due) || (isToday && due < start),
               let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), date > now {
                let name = settings.medicationName.isEmpty ? String(localized: "your medication") : settings.medicationName
                reminders.append(Reminder(id: "medication.\(key)", date: date,
                                          title: String(localized: "Dose due today"),
                                          body: String(localized: "Time for \(name). Log it in Stride so the next date and injection site stay right.")))
            }

            if let hour = settings.weighInHour, !paused, !(isToday && today.weighedIn),
               let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), date > now {
                reminders.append(Reminder(id: "weighin.\(key)", date: date,
                                          title: String(localized: "Morning weigh-in"),
                                          body: String(localized: "Step on the scale before breakfast and log it. Consistency beats perfection.")))
            }

            if settings.waterEnabled, !(isToday && today.waterMl >= settings.waterGoalMl) {
                for hour in waterHours {
                    guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), date > now else { continue }
                    reminders.append(Reminder(id: "water.\(key).\(hour)", date: date,
                                              title: String(localized: "Time for a glass of water"),
                                              body: String(localized: "A quick sip now keeps hunger and headaches away.")))
                }
            }

            if settings.mealsEnabled, !paused {
                for slot in mealTimes {
                    guard let date = calendar.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: day),
                          date > now else { continue }
                    if isToday, today.loggedMeals.contains(slot.meal) { continue }
                    let nothingYet = isToday && slot.meal == .lunch && today.loggedMeals.isEmpty
                    reminders.append(Reminder(
                        id: "meal.\(key).\(slot.meal.rawValue)", date: date,
                        title: nothingYet ? String(localized: "Nothing logged yet today") : String(localized: "Log your \(slot.meal.inSentence)"),
                        body: nothingYet ? String(localized: "A quick log of breakfast and lunch keeps today's numbers useful.")
                                         : settings.hideNumbers ? String(localized: "Logging right after you eat keeps your day honest.")
                                         : String(localized: "Logging right after you eat keeps your calorie count honest.")))
                }
            }

            if let hour = settings.dayCloseHour, !paused,
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
        if let hour = settings.proteinHour, !settings.hideNumbers, today.proteinShortG >= proteinNudgeMinimumG,
           !isPaused(start, settings.pause, calendar: calendar),
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

    private static func isPaused(_ day: Date, _ pause: DateInterval?, calendar: Calendar) -> Bool {
        guard let pause else { return false }
        return day >= calendar.startOfDay(for: pause.start) && day < calendar.startOfDay(for: pause.end)
    }

    private static func dayKey(_ day: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
