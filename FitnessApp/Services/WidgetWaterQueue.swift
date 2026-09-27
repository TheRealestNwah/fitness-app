import Foundation
import SwiftData

/// Water logged from the widget's button. The widget can't open the app's store, so it queues
/// glasses in the shared App Group (see StrideWidgets/LogGlassIntent.swift) and the app adds
/// them to the diary the next time it comes to the foreground.
enum WidgetWaterQueue {
    struct Pending: Codable, Equatable {
        var id: UUID
        var date: Date
        var ml: Double
    }

    static let key = "pendingWater"

    static func pending(in defaults: UserDefaults?) -> [Pending] {
        guard let data = defaults?.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Pending].self, from: data)) ?? []
    }

    /// Moves queued glasses into the diary, once each, and empties the queue.
    @MainActor
    @discardableResult
    static func drain(into context: ModelContext,
                      defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) -> Int {
        let queued = pending(in: defaults)
        guard !queued.isEmpty else { return 0 }
        defaults?.removeObject(forKey: key)
        var added = 0
        for glass in queued where glass.ml > 0 && glass.ml <= 5000 {
            let id = glass.id
            let existing = (try? context.fetchCount(FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.uuid == id }))) ?? 0
            guard existing == 0 else { continue }
            let entry = WaterEntry(date: glass.date, amountMl: glass.ml)
            entry.uuid = glass.id
            context.insertWater(entry)
            added += 1
        }
        if added > 0 { try? context.save() }
        return added
    }
}
