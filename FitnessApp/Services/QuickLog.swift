import Foundation
import SwiftData

enum QuickLogError: Error, Equatable, LocalizedError {
    case noProfile
    case waterOutOfRange
    case weightOutOfRange

    var errorDescription: String? {
        switch self {
        case .noProfile: "Open Stride and finish setting up first."
        case .waterOutOfRange: "That's more water than Stride logs at once. Try up to 5 litres."
        case .weightOutOfRange: "That weight doesn't look right. Try again between 20 and 400 kg."
        }
    }
}

/// The actions Siri and Shortcuts can run, kept apart from the App Intents so they can be tested.
/// Each goes through the same paths as the app: Health export, then widget and watch refresh.
@MainActor
enum QuickLog {
    static func profile(in context: ModelContext) -> UserProfile? {
        try? context.fetch(FetchDescriptor<UserProfile>()).first
    }

    static func units(in context: ModelContext) -> Units {
        profile(in: context)?.units ?? Units(system: .metric)
    }

    /// Logs water (one glass when no amount is given) and returns today's total in millilitres.
    @discardableResult
    static func water(ml: Double?, context: ModelContext, now: Date = .now) throws -> Double {
        let amount = ml ?? units(in: context).glassMl
        guard amount > 0, amount <= 5000 else { throw QuickLogError.waterOutOfRange }
        context.insertWater(WaterEntry(date: now, amountMl: amount))
        try context.save()
        if let profile = profile(in: context) { WidgetSnapshot.publish(profile: profile) }
        let start = now.startOfDay
        let today = try context.fetch(FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.date >= start }))
        return today.filter { $0.date <= now }.reduce(0) { $0 + $1.amountMl }
    }

    /// Adds a weigh-in, mirroring it to Apple Health like the weigh-in sheet does.
    @discardableResult
    static func weight(kg: Double, context: ModelContext, now: Date = .now) throws -> WeightEntry {
        guard (20...400).contains(kg) else { throw QuickLogError.weightOutOfRange }
        let entry = WeightEntry(date: now, weightKg: kg)
        context.insert(entry)
        try context.save()
        if HealthSettings.isEnabled, HealthKitManager.isAvailable {
            Task { @MainActor in
                if let id = try? await HealthKitManager.shared.saveWeight(kg: kg, date: now) {
                    entry.sourceID = id.uuidString
                    try? context.save()
                }
            }
        }
        if let profile = profile(in: context) { WidgetSnapshot.publish(profile: profile) }
        return entry
    }

    /// Calories left today (negative when over).
    static func caloriesLeft(context: ModelContext, now: Date = .now) throws -> Double {
        guard let profile = profile(in: context),
              let snapshot = WidgetSnapshot.current(profile: profile, now: now) else { throw QuickLogError.noProfile }
        return snapshot.remainingKcal
    }
}
