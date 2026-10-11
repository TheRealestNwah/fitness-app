import Foundation

/// Mirror of the app's `WidgetSnapshot`: the app encodes it into the shared App Group.
struct Snapshot: Codable {
    var day: Date
    var consumedKcal: Double
    var targetKcal: Int
    var waterMl: Double
    var waterGoalMl: Double
    var weightText: String?
    var streak: Int
    var energyUnit: String
    var glassMl: Double? = nil
    var proteinG: Double? = nil
    var proteinTargetG: Double? = nil
    /// The person's volume unit ("ml" or "fl oz"); absent in older snapshots, which mean ml.
    var waterUnit: String? = nil

    static let appGroup = "group.com.stride.FitnessApp"
    static let key = "todaySnapshot"

    static let placeholder = Snapshot(day: .now, consumedKcal: 1240, targetKcal: 1850, waterMl: 1500,
                                      waterGoalMl: 2500, weightText: "72.4 kg", streak: 12, energyUnit: "kcal",
                                      proteinG: 82, proteinTargetG: 120)

    /// The last snapshot the app saved. A snapshot from an earlier day means nothing is
    /// logged yet today, so its totals start again from zero.
    static func load(now: Date = .now) -> Snapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key),
              var snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return nil }
        if !Calendar.current.isDate(snapshot.day, inSameDayAs: now) {
            snapshot.day = Calendar.current.startOfDay(for: now)
            snapshot.consumedKcal = 0
            snapshot.waterMl = 0
            if snapshot.proteinG != nil { snapshot.proteinG = 0 }
        }
        return snapshot
    }

    var remainingKcal: Double { Double(targetKcal) - consumedKcal }
    var progress: Double { targetKcal > 0 ? consumedKcal / Double(targetKcal) : 0 }
    var waterProgress: Double { waterGoalMl > 0 ? waterMl / waterGoalMl : 0 }
    var proteinProgress: Double {
        guard let proteinG, let proteinTargetG, proteinTargetG > 0 else { return 0 }
        return proteinG / proteinTargetG
    }

    var usesFlOz: Bool { waterUnit == "fl oz" }
    var waterUnitLabel: String { usesFlOz ? "fl oz" : "ml" }
    /// Quick-add amounts in ml: 250 and 500 ml, or 8 and 16 fl oz.
    var quickWaterMl: [Double] { usesFlOz ? [236.6, 473.2] : [250, 500] }

    /// `ml` in the person's unit, rounded for display.
    func waterAmount(_ ml: Double) -> Int {
        usesFlOz ? Int((ml * 0.033814).rounded()) : Int(ml.rounded())
    }

    func energy(_ kcal: Double) -> String {
        energyUnit == "kJ" ? "\(Int((kcal * 4.184).rounded()))" : "\(Int(kcal.rounded()))"
    }
}
