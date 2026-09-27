import Foundation
import SwiftData
import WatchConnectivity

/// A glass of water logged on the watch. The watch sends it as a WatchConnectivity user info
/// dictionary (see StrideWatch/WatchStore.swift) and the phone turns it into a `WaterEntry`.
struct WatchWaterLog: Equatable {
    var id: UUID
    var date: Date
    var amountMl: Double

    static let kind = "water"

    init(id: UUID = UUID(), date: Date, amountMl: Double) {
        self.id = id
        self.date = date
        self.amountMl = amountMl
    }

    var userInfo: [String: Any] {
        ["kind": Self.kind, "id": id.uuidString, "date": date.timeIntervalSince1970, "amountMl": amountMl]
    }

    /// Nil for anything that isn't a sensible water log, so a bad message can't add junk to the diary.
    init?(userInfo: [String: Any]) {
        guard userInfo["kind"] as? String == Self.kind,
              let id = (userInfo["id"] as? String).flatMap(UUID.init(uuidString:)),
              let seconds = userInfo["date"] as? Double,
              let amount = userInfo["amountMl"] as? Double,
              amount > 0, amount <= 5000 else { return nil }
        self.init(id: id, date: Date(timeIntervalSince1970: seconds), amountMl: amount)
    }
}

/// Keeps the watch app in step with the phone: sends today's snapshot to the watch and
/// records water logged there.
@MainActor
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    private var container: ModelContainer?
    private var lastSnapshot: Data?

    func start(container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sends the latest snapshot as the application context, which the watch reads whenever it
    /// next wakes. Only the newest context is ever delivered, so repeat sends are cheap.
    func send(snapshot: Data) {
        guard snapshot != lastSnapshot else { return }
        lastSnapshot = snapshot
        pushSnapshot()
    }

    private func pushSnapshot() {
        guard let snapshot = lastSnapshot, WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext(["snapshot": snapshot])
    }

    /// Adds the watch's water log to the diary once, however many times it arrives.
    func record(_ log: WatchWaterLog) {
        guard let context = container?.mainContext else { return }
        let id = log.id
        let existing = (try? context.fetchCount(FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.uuid == id }))) ?? 0
        guard existing == 0 else { return }
        let entry = WaterEntry(date: log.date, amountMl: log.amountMl)
        entry.uuid = log.id
        context.insert(entry)
        try? context.save()
        if let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first {
            WidgetSnapshot.publish(profile: profile)
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in self.pushSnapshot() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switching to another watch: reactivate so the new one gets updates.
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.pushSnapshot() }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let log = WatchWaterLog(userInfo: userInfo) else { return }
        Task { @MainActor in self.record(log) }
    }
}
