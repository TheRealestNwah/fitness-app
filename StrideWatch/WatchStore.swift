import Foundation
import WatchConnectivity
import WidgetKit

/// A food the phone offers for one-tap logging. Mirrors `WatchQuickFood` in the iPhone app.
struct QuickFood: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var servings: Double
    var kcal: Double
}

/// Today's totals from the phone, plus water and food logging that the phone records in the diary.
/// The snapshot is kept in the watch's App Group so the complication can read it too.
@MainActor
final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var quickFoods: [QuickFood] = []

    private static let quickFoodsKey = "watchQuickFoods"

    override init() {
        super.init()
        snapshot = Snapshot.load()
        if let data = UserDefaults.standard.data(forKey: Self.quickFoodsKey) { applyQuickFoods(data) }
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

    /// Logs one of the phone's quick foods at its usual amount.
    func log(_ food: QuickFood) {
        sendFood(["foodID": food.id.uuidString, "servings": food.servings], kcal: food.kcal)
    }

    /// Logs a calorie amount without a food.
    func quickAdd(kcal: Double) {
        guard kcal > 0 else { return }
        sendFood(["kcal": kcal], kcal: kcal)
    }

    private func sendFood(_ fields: [String: Any], kcal: Double) {
        let now = Date.now
        // Mirrors WatchFoodLog in the iPhone app.
        var info: [String: Any] = ["kind": "food", "id": UUID().uuidString, "date": now.timeIntervalSince1970]
        info.merge(fields) { _, new in new }
        WCSession.default.transferUserInfo(info)
        guard var current = Snapshot.load(now: now) else { return }
        current.consumedKcal += kcal
        save(current)
    }

    private func apply(_ data: Data) {
        guard let received = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        save(received)
    }

    private func applyQuickFoods(_ data: Data) {
        guard let foods = try? JSONDecoder().decode([QuickFood].self, from: data) else { return }
        quickFoods = foods
        UserDefaults.standard.set(data, forKey: Self.quickFoodsKey)
    }

    private func save(_ new: Snapshot) {
        guard let data = try? JSONEncoder().encode(new) else { return }
        UserDefaults(suiteName: Snapshot.appGroup)?.set(data, forKey: Snapshot.key)
        snapshot = Snapshot.load() ?? new
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func receive(snapshot: Data?, quickFoods: Data?) {
        if let snapshot { apply(snapshot) }
        if let quickFoods { applyQuickFoods(quickFoods) }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        let context = session.receivedApplicationContext
        let snapshot = context["snapshot"] as? Data, foods = context["quickFoods"] as? Data
        Task { @MainActor in self.receive(snapshot: snapshot, quickFoods: foods) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let snapshot = applicationContext["snapshot"] as? Data, foods = applicationContext["quickFoods"] as? Data
        Task { @MainActor in self.receive(snapshot: snapshot, quickFoods: foods) }
    }
}
