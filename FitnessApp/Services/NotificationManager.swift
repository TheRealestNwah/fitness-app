import Foundation
import SwiftData
import UserNotifications

/// Schedules the local reminders configured in Settings.
///
/// The weigh-in reminder repeats daily. Water and meal reminders are one-offs for the next
/// few days (see `ReminderPlanner`), rebuilt whenever the app opens or saves data, so today's
/// can react to what has been logged.
enum NotificationManager {
    private static let weighInID = "reminder.weighin"
    private static let plannedPrefix = "reminder."

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

        if profile.weighInReminderEnabled {
            let content = UNMutableNotificationContent()
            content.title = "Morning weigh-in"
            content.body = "Step on the scale before breakfast and log it. Consistency beats perfection."
            content.sound = .default
            var comps = DateComponents()
            comps.hour = profile.weighInReminderHour
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: weighInID, content: content, trigger: trigger))
        }

        guard profile.waterReminderEnabled || profile.mealReminderEnabled else { return }
        let settings = ReminderPlanner.Settings(waterEnabled: profile.waterReminderEnabled,
                                                waterGoalMl: profile.waterGoalMl,
                                                mealsEnabled: profile.mealReminderEnabled)
        for reminder in ReminderPlanner.plan(settings: settings, today: todaysLog(profile.modelContext, now: now), now: now) {
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
    private static func todaysLog(_ context: ModelContext?, now: Date) -> ReminderPlanner.Today {
        guard let context else { return .init(waterMl: 0, loggedMeals: []) }
        let start = Calendar.current.startOfDay(for: now)
        let end = start.adding(days: 1)
        let water = (try? context.fetch(FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? []
        let food = (try? context.fetch(FetchDescriptor<FoodLogEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? []
        return .init(waterMl: water.reduce(0) { $0 + $1.amountMl }, loggedMeals: Set(food.map(\.mealType)))
    }
}
