import Foundation
import WatchConnectivity
import WidgetKit

/// Today's totals from the phone, plus water logging that the phone records in the diary.
/// The snapshot is kept in the watch's App Group so the complication can read it too.
@MainActor
final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot: Snapshot?

    override init() {
        super.init()
        snapshot = Snapshot.load()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Queues the log for the phone (delivered even if it's out of range right now) and shows
    /// it straight away; the phone's next snapshot replaces the estimate.
    func logWater(_ ml: Double) {
        let now = Date.now
        // Mirrors WatchWaterLog in the iPhone app.
        WCSession.default.transferUserInfo(["kind": "water", "id": UUID().uuidString,
                                            "date": now.timeIntervalSince1970, "amountMl": ml])
        guard var current = Snapshot.load(now: now) else { return }
        current.waterMl += ml
        save(current)
    }

    private func apply(_ data: Data) {
        guard let received = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        save(received)
    }

    private func save(_ new: Snapshot) {
        guard let data = try? JSONEncoder().encode(new) else { return }
        UserDefaults(suiteName: Snapshot.appGroup)?.set(data, forKey: Snapshot.key)
        snapshot = Snapshot.load() ?? new
        WidgetCenter.shared.reloadAllTimelines()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        guard let data = session.receivedApplicationContext["snapshot"] as? Data else { return }
        Task { @MainActor in self.apply(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["snapshot"] as? Data else { return }
        Task { @MainActor in self.apply(data) }
    }
}
