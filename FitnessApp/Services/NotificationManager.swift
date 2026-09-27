import Foundation
import UserNotifications

/// Schedules the local reminders configured in Settings.
enum NotificationManager {
    private static let weighInID = "reminder.weighin"
    private static let waterPrefix = "reminder.water."
    private static let mealPrefix = "reminder.meal."

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Rebuilds every reminder from the profile's current preferences.
    static func sync(with profile: UserProfile) {
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

        if profile.waterReminderEnabled {
            for hour in stride(from: 9, through: 21, by: 2) {
                let content = UNMutableNotificationContent()
                content.title = "Time for a glass of water"
                content.body = "A quick sip now keeps hunger and headaches away."
                content.sound = .default
                var comps = DateComponents()
                comps.hour = hour
                comps.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                center.add(UNNotificationRequest(identifier: waterPrefix + String(hour), content: content, trigger: trigger))
            }
        }

        if profile.mealReminderEnabled {
            let slots: [(MealType, Int)] = [(.breakfast, 8), (.lunch, 13), (.dinner, 19)]
            for (meal, hour) in slots {
                let content = UNMutableNotificationContent()
                content.title = "Log your \(meal.label.lowercased())"
                content.body = "Logging right after you eat keeps your calorie count honest."
                content.sound = .default
                var comps = DateComponents()
                comps.hour = hour
                comps.minute = 30
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                center.add(UNNotificationRequest(identifier: mealPrefix + meal.rawValue, content: content, trigger: trigger))
            }
        }
    }
}
