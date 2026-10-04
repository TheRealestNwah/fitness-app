#if os(iOS)
import BackgroundTasks
#endif
import Foundation
import SwiftData

/// Work that shouldn't wait for the app to be opened: glasses logged from the widget reach the
/// diary (and Apple Health), Health imports run, and the widget and watch get a fresh snapshot.
enum BackgroundRefresh {
    static let identifier = "com.stride.FitnessApp.refresh"

    /// Roughly every few hours, but shortly after midnight when that comes sooner, so the
    /// widgets and watch start the new day from the store rather than a guess.
    static func earliestBegin(after now: Date, interval: TimeInterval = 3 * 3600,
                              calendar: Calendar = .current) -> Date {
        let regular = now.addingTimeInterval(interval)
        guard let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return regular }
        let afterMidnight = midnight.addingTimeInterval(5 * 60)
        return min(regular, afterMidnight)
    }

    /// Asks iOS for the next run; it decides when, no earlier than `earliestBegin`.
    static func schedule(now: Date = .now) {
        #if os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBegin(after: now)
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }

    @MainActor
    static func run() async {
        schedule()
        let context = AppStore.container.mainContext
        WidgetWaterQueue.drain(into: context)
        _ = await HealthKitManager.shared.importIfDue(into: context)
        try? context.save()
        FastingActivityManager.sync(context: context)
        if let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first {
            WidgetSnapshot.publish(profile: profile)
        }
    }
}
