import Foundation
import SwiftData
import WidgetKit

/// What the widgets show, written by the app to the shared App Group after every change.
/// The widget extension decodes the same JSON (see StrideWidgets/Snapshot.swift).
struct WidgetSnapshot: Codable, Equatable {
    var day: Date
    var consumedKcal: Double
    var targetKcal: Int
    var waterMl: Double
    var waterGoalMl: Double
    var weightText: String?
    var streak: Int
    var energyUnit: String

    static let appGroup = "group.com.stride.FitnessApp"
    static let key = "todaySnapshot"

    var remainingKcal: Double { Double(targetKcal) - consumedKcal }

    static func make(profile: UserProfile, food: [(date: Date, calories: Double)], water: [(date: Date, ml: Double)],
                     latestWeightKg: Double?, logDates: [Date], now: Date = .now,
                     calendar: Calendar = .current) -> WidgetSnapshot {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        let today = { (date: Date) in date >= start && date < end }
        let currentKg = latestWeightKg ?? profile.startWeightKg
        return WidgetSnapshot(
            day: start,
            consumedKcal: food.filter { today($0.date) }.reduce(0) { $0 + $1.calories },
            targetKcal: profile.calorieTarget(currentWeightKg: currentKg),
            waterMl: water.filter { today($0.date) }.reduce(0) { $0 + $1.ml },
            waterGoalMl: profile.waterGoalMl,
            weightText: latestWeightKg.map { profile.units.weightString(kg: $0) },
            streak: NutritionCalculator.streak(logDates: logDates, today: now, calendar: calendar),
            energyUnit: EnergyUnit.current.rawValue)
    }

    /// Recomputes today's snapshot from the store, saves it for the widgets and asks them to reload.
    @MainActor
    static func publish(profile: UserProfile) {
        guard let context = profile.modelContext else { return }
        let since = Calendar.current.date(byAdding: .day, value: -60, to: .now.startOfDay) ?? .now
        let food = (try? context.fetch(FetchDescriptor<FoodLogEntry>(predicate: #Predicate { $0.date >= since }))) ?? []
        let water = (try? context.fetch(FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.date >= since }))) ?? []
        var latest = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        latest.fetchLimit = 1
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>(predicate: #Predicate { $0.date >= since }))) ?? []
        let snapshot = make(profile: profile,
                            food: food.map { (date: $0.date, calories: $0.calories) },
                            water: water.map { (date: $0.date, ml: $0.amountMl) },
                            latestWeightKg: (try? context.fetch(latest))?.first?.weightKg,
                            logDates: food.map(\.date) + weights.map(\.date))
        guard let data = try? JSONEncoder().encode(snapshot),
              let shared = UserDefaults(suiteName: appGroup) else { return }
        if shared.data(forKey: key) != data {
            shared.set(data, forKey: key)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
