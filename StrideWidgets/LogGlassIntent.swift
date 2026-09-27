#if os(iOS)
import AppIntents
import Foundation
import WidgetKit

/// The widget's +glass button. Queues the glass for the app (which owns the diary) and bumps
/// the saved snapshot so the widget shows it straight away. Mirrors WidgetWaterQueue in the app.
struct LogGlassIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Glass of Water"
    static var isDiscoverable = false

    private struct Pending: Codable {
        var id: UUID
        var date: Date
        var ml: Double
    }

    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: Snapshot.appGroup) else { return .result() }
        let now = Date.now
        let current = Snapshot.load(now: now)
        let ml = current?.glassMl ?? 250

        var queue = (defaults.data(forKey: "pendingWater")).flatMap { try? JSONDecoder().decode([Pending].self, from: $0) } ?? []
        queue.append(Pending(id: UUID(), date: now, ml: ml))
        if let data = try? JSONEncoder().encode(queue) { defaults.set(data, forKey: "pendingWater") }

        if var snapshot = current {
            snapshot.waterMl += ml
            if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: Snapshot.key) }
        }
        return .result()
    }
}
#endif
