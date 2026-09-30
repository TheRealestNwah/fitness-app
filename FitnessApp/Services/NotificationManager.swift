import Foundation
import SwiftData
import UserNotifications

/// Schedules the local reminders configured in Settings.
///
/// Every reminder is a one-off for the next few days (see `ReminderPlanner`), rebuilt whenever
/// the app opens or saves data, so today's can react to what has been logged.
enum NotificationManager {
    private static let plannedPrefix = "reminder."

    /// Whether any reminder is switched on, and so whether notification permission is needed.
    static func anyReminderEnabled(_ profile: UserProfile) -> Bool {
        profile.weighInReminderEnabled || profile.waterReminderEnabled || profile.mealReminderEnabled
            || profile.dayCloseReminderHour != nil || profile.proteinReminderEnabled
    }

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Rebuilds every reminder from the profile's preferences and today's log.
    @MainActor
    static func sync(with profile: UserProfile, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard anyReminderEnabled(profile) else { return }
        var pause: DateInterval?
        if profile.pauseRemindersOnDietBreak, let start = profile.dietBreakStart, let end = profile.dietBreakEnd, end > start {
            pause = DateInterval(start: start, end: end)
        }
        let settings = ReminderPlanner.Settings(waterEnabled: profile.waterReminderEnabled,
                                                waterGoalMl: profile.waterGoalMl,
                                                mealsEnabled: profile.mealReminderEnabled,
                                                dayCloseHour: profile.dayCloseReminderHour,
                                                proteinHour: profile.proteinReminderEnabled ? proteinHour : nil,
                                                weighInHour: profile.weighInReminderEnabled ? profile.weighInReminderHour : nil,
                                                pause: pause)
        for reminder in ReminderPlanner.plan(settings: settings, today: todaysLog(profile, now: now), now: now) {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: plannedPrefix + reminder.id, content: content, trigger: trigger))
        }
    }

    @MainActor
    /// 5 pm: late enough to know, early enough to fix at dinner.
    static let proteinHour = 17

    @MainActor
    private static func todaysLog(_ profile: UserProfile, now: Date) -> ReminderPlanner.Today {
        guard let context = profile.modelContext else { return .init(waterMl: 0, loggedMeals: []) }
        let start = Calendar.current.startOfDay(for: now)
        let end = start.adding(days: 1)
        let water = (try? context.fetch(FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? []
        let food = (try? context.fetch(FetchDescriptor<FoodLogEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? []
        let weighIns = (try? context.fetchCount(FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? 0
        var today = ReminderPlanner.Today(waterMl: water.reduce(0) { $0 + $1.amountMl }, loggedMeals: Set(food.map(\.mealType)))
        today.weighedIn = weighIns > 0
        guard profile.proteinReminderEnabled else { return today }
        let latestKg = (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])).first?.weightKg)
            ?? profile.startWeightKg
        let target = profile.macroTargets(currentWeightKg: latestKg)
        today.proteinShortG = max(target.protein - food.reduce(0) { $0 + $1.protein }, 0)
        let kcalLeft = Double(profile.calorieTarget(currentWeightKg: latestKg)) - food.reduce(0) { $0 + $1.calories }
        let saved = ((try? context.fetch(FetchDescriptor<FoodItem>())) ?? [])
            .filter { $0.isFavorite || $0.lastUsed != nil }
            .map { (name: $0.displayName, protein: $0.protein, kcal: $0.calories) }
        today.proteinIdea = ReminderPlanner.proteinIdea(foods: saved, shortG: today.proteinShortG, kcalLeft: kcalLeft)
        return today
    }
}
