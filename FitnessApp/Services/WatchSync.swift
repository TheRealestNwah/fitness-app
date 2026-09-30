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

/// Food logged on the watch: one of the quick foods the phone sent (by the food's id), or a
/// quick-add calorie amount. Mirrors StrideWatch/WatchStore.swift.
struct WatchFoodLog: Equatable {
    var id: UUID
    var date: Date
    /// The food to log, or nil for a quick add.
    var foodID: UUID?
    var servings: Double
    /// Calories for a quick add.
    var kcal: Double

    static let kind = "food"

    init(id: UUID = UUID(), date: Date, foodID: UUID?, servings: Double = 1, kcal: Double = 0) {
        self.id = id
        self.date = date
        self.foodID = foodID
        self.servings = servings
        self.kcal = kcal
    }

    var userInfo: [String: Any] {
        var info: [String: Any] = ["kind": Self.kind, "id": id.uuidString, "date": date.timeIntervalSince1970,
                                   "servings": servings, "kcal": kcal]
        if let foodID { info["foodID"] = foodID.uuidString }
        return info
    }

    /// Nil for anything that isn't a sensible food log.
    init?(userInfo: [String: Any]) {
        guard userInfo["kind"] as? String == Self.kind,
              let id = (userInfo["id"] as? String).flatMap(UUID.init(uuidString:)),
              let seconds = userInfo["date"] as? Double else { return nil }
        let foodID = (userInfo["foodID"] as? String).flatMap(UUID.init(uuidString:))
        let servings = userInfo["servings"] as? Double ?? 1
        let kcal = userInfo["kcal"] as? Double ?? 0
        if foodID != nil {
            guard servings > 0, servings <= 20 else { return nil }
        } else {
            guard kcal > 0, kcal <= 5000 else { return nil }
        }
        self.init(id: id, date: Date(timeIntervalSince1970: seconds), foodID: foodID, servings: servings, kcal: kcal)
    }
}

/// A food offered for one-tap logging on the watch. Encoded into the watch's application context.
struct WatchQuickFood: Codable, Equatable {
    var id: UUID
    var name: String
    var servings: Double
    var kcal: Double

    static let limit = 8

    struct Candidate {
        var id: UUID
        var name: String
        var kcalPerServing: Double
        var lastServings: Double?
        var isFavorite: Bool
        var lastUsed: Date?
    }

    /// Favourites first, then the most recently used, each at the amount last logged.
    static func pick(_ foods: [Candidate], limit: Int = limit) -> [WatchQuickFood] {
        foods.filter { $0.isFavorite || $0.lastUsed != nil }
            .sorted { a, b in
                if a.isFavorite != b.isFavorite { return a.isFavorite }
                return (a.lastUsed ?? .distantPast) > (b.lastUsed ?? .distantPast)
            }
            .prefix(limit)
            .map { food in
                let servings = food.lastServings ?? 1
                return WatchQuickFood(id: food.id, name: food.name, servings: servings, kcal: food.kcalPerServing * servings)
            }
    }
}

/// Keeps the watch app in step with the phone: sends today's snapshot and quick foods to the
/// watch, and records water and food logged there.
@MainActor
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    private var container: ModelContainer?
    private var lastSnapshot: Data?
    private var lastQuickFoods: Data?

    func start(container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sends the latest snapshot as the application context, which the watch reads whenever it
    /// next wakes. Only the newest context is ever delivered, so repeat sends are cheap.
    func send(snapshot: Data, quickFoods: Data? = nil) {
        guard snapshot != lastSnapshot || (quickFoods != nil && quickFoods != lastQuickFoods) else { return }
        lastSnapshot = snapshot
        if let quickFoods { lastQuickFoods = quickFoods }
        pushSnapshot()
    }

    private func pushSnapshot() {
        guard let snapshot = lastSnapshot, WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        var context: [String: Any] = ["snapshot": snapshot]
        if let lastQuickFoods { context["quickFoods"] = lastQuickFoods }
        try? session.updateApplicationContext(context)
    }

    /// The quick foods for the watch, from the phone's favourites and recent foods.
    static func quickFoods(in context: ModelContext) -> Data? {
        let foods = (try? context.fetch(FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.isFavorite || $0.lastUsed != nil }))) ?? []
        let picked = WatchQuickFood.pick(foods.map {
            WatchQuickFood.Candidate(id: $0.uuid, name: $0.displayName, kcalPerServing: $0.calories,
                                     lastServings: $0.lastServings, isFavorite: $0.isFavorite, lastUsed: $0.lastUsed)
        })
        return try? JSONEncoder().encode(picked)
    }

    /// Adds food logged on the watch to the diary once, in the meal for the time it was logged.
    func record(_ log: WatchFoodLog) {
        guard let context = container?.mainContext else { return }
        let id = log.id
        let existing = (try? context.fetchCount(FetchDescriptor<FoodLogEntry>(predicate: #Predicate { $0.uuid == id }))) ?? 0
        guard existing == 0 else { return }
        let meal = MealType.current(at: log.date)
        let entry: FoodLogEntry
        if let foodID = log.foodID {
            guard let food = try? context.fetch(FetchDescriptor<FoodItem>(predicate: #Predicate { $0.uuid == foodID })).first
            else { return }
            let s = log.servings
            entry = FoodLogEntry(date: log.date, mealType: meal, foodName: food.displayName, servings: s,
                                 servingDescription: food.servingDescription, calories: food.calories * s,
                                 protein: food.protein * s, carbs: food.carbs * s, fat: food.fat * s, foodItemID: food.uuid,
                                 fiber: food.fiber * s, sugar: food.sugar * s, sodium: food.sodium * s)
                .withExtras(from: food, servings: s)
            food.lastServings = s
            food.lastUsed = .now
            food.useCount += 1
        } else {
            entry = FoodLogEntry(date: log.date, mealType: meal, foodName: String(localized: "Quick add"), servings: 1,
                                 servingDescription: "", calories: log.kcal, protein: 0, carbs: 0, fat: 0)
        }
        // The watch's id, so a repeat delivery is recognised.
        entry.uuid = log.id
        context.insertDiaryEntry(entry)
        try? context.save()
        if let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first {
            WidgetSnapshot.publish(profile: profile)
        }
    }

    /// Adds the watch's water log to the diary once, however many times it arrives.
    func record(_ log: WatchWaterLog) {
        guard let context = container?.mainContext else { return }
        let id = log.id
        let existing = (try? context.fetchCount(FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.uuid == id }))) ?? 0
        guard existing == 0 else { return }
        let entry = WaterEntry(date: log.date, amountMl: log.amountMl)
        entry.uuid = log.id
        context.insertWater(entry)
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
        if let log = WatchWaterLog(userInfo: userInfo) {
            Task { @MainActor in self.record(log) }
        } else if let log = WatchFoodLog(userInfo: userInfo) {
            Task { @MainActor in self.record(log) }
        }
    }
}
