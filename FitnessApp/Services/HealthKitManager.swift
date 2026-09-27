import Foundation
import HealthKit
import Observation
import SwiftData

enum HealthKitError: LocalizedError {
    case unavailable
    var errorDescription: String? { "Apple Health isn't available on this device." }
}

/// Settings live in UserDefaults so the manager can act without a profile in hand.
enum HealthSettings {
    static let enabledKey = "healthKitEnabled"
    static let creditPercentKey = "healthActiveEnergyCreditPercent"
    static let lastImportKey = "healthLastImport"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
    /// 0, 50 or 100: how much of today's active energy is added to the calorie budget.
    static var creditPercent: Int {
        get { UserDefaults.standard.integer(forKey: creditPercentKey) }
        set { UserDefaults.standard.set(newValue, forKey: creditPercentKey) }
    }
    static var lastImport: Date? {
        get { UserDefaults.standard.object(forKey: lastImportKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastImportKey) }
    }
}

struct HealthQuantitySample: Equatable {
    var id: UUID
    var date: Date
    var value: Double
    var fromThisApp: Bool
}

struct HealthSleepInterval: Equatable {
    var start: Date
    var end: Date
}

struct HealthImportSummary: Equatable {
    var weighIns = 0
    var restingHeartRateDays = 0
    var sleepNights = 0
    var workouts = 0

    var description: String {
        var parts: [String] = []
        if weighIns > 0 { parts.append("\(weighIns) weigh-in\(weighIns == 1 ? "" : "s")") }
        if restingHeartRateDays > 0 { parts.append("\(restingHeartRateDays) resting heart rate\(restingHeartRateDays == 1 ? "" : "s")") }
        if sleepNights > 0 { parts.append("\(sleepNights) night\(sleepNights == 1 ? "" : "s") of sleep") }
        if workouts > 0 { parts.append("\(workouts) workout\(workouts == 1 ? "" : "s")") }
        return parts.isEmpty ? "Nothing new to import" : "Imported " + parts.joined(separator: ", ")
    }
}

/// Pure helpers so the import rules can be unit-tested without HealthKit.
enum HealthImportRules {
    static let metadataKey = "StrideEntryID"

    /// Samples worth importing: not written by this app, and not already imported.
    static func newSamples(_ samples: [HealthQuantitySample], existingIDs: Set<String>) -> [HealthQuantitySample] {
        samples.filter { !$0.fromThisApp && !existingIDs.contains($0.id.uuidString) }
    }

    /// Hours asleep per night, keyed by the start of the day the person woke up.
    static func sleepHoursByNight(_ intervals: [HealthSleepInterval], calendar: Calendar = .current) -> [Date: Double] {
        var hours: [Date: Double] = [:]
        for interval in intervals where interval.end > interval.start {
            let night = calendar.startOfDay(for: interval.end)
            hours[night, default: 0] += interval.end.timeIntervalSince(interval.start) / 3600
        }
        return hours
    }

    /// Latest reading per day.
    static func latestPerDay(_ samples: [HealthQuantitySample], calendar: Calendar = .current) -> [Date: HealthQuantitySample] {
        var latest: [Date: HealthQuantitySample] = [:]
        for s in samples {
            let day = calendar.startOfDay(for: s.date)
            if let existing = latest[day], existing.date > s.date { continue }
            latest[day] = s
        }
        return latest
    }

    static func activeEnergyCredit(activeKcal: Double, percent: Int) -> Int {
        guard percent > 0, activeKcal > 0 else { return 0 }
        return Int((activeKcal * Double(percent) / 100).rounded())
    }

    /// A readable name for a HealthKit workout type's raw value.
    static func workoutName(_ rawType: UInt) -> String {
        switch HKWorkoutActivityType(rawValue: rawType) {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .dance, .cardioDance, .socialDance: return "Dancing"
        case .stairClimbing, .stairs: return "Stair climbing"
        case .tennis: return "Tennis"
        case .soccer: return "Football"
        default: return "Workout"
        }
    }

    static func vitalsSourceID(for day: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "health:%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

@MainActor
@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    var todaySteps: Int = 0
    var todayActiveEnergyKcal: Double = 0
    var lastRefresh: Date?
    var lastError: String?

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Calories added to today's budget from active energy, per the user's chosen share.
    var activeEnergyCredit: Int {
        guard HealthSettings.isEnabled else { return 0 }
        return HealthImportRules.activeEnergyCredit(activeKcal: todayActiveEnergyKcal, percent: HealthSettings.creditPercent)
    }

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.bodyMass), HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned),
         HKQuantityType(.restingHeartRate), HKCategoryType(.sleepAnalysis), HKObjectType.workoutType()]
    }

    private var writeTypes: Set<HKSampleType> {
        [HKQuantityType(.bodyMass), HKQuantityType(.dietaryEnergyConsumed), HKQuantityType(.dietaryProtein),
         HKQuantityType(.dietaryCarbohydrates), HKQuantityType(.dietaryFatTotal)]
    }

    // MARK: Authorization

    func requestAuthorization() async throws {
        guard Self.isAvailable else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    // MARK: Reads

    private func quantitySamples(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, since: Date) async throws -> [HealthQuantitySample] {
        let type = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: predicate)],
                                                 sortDescriptors: [SortDescriptor(\.startDate)])
        let results = try await descriptor.result(for: store)
        let bundle = Bundle.main.bundleIdentifier ?? ""
        return results.map {
            HealthQuantitySample(id: $0.uuid, date: $0.startDate, value: $0.quantity.doubleValue(for: unit),
                                 fromThisApp: $0.sourceRevision.source.bundleIdentifier == bundle)
        }
    }

    private func sleepIntervals(since: Date) async throws -> [HealthSleepInterval] {
        let type = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: type, predicate: predicate)],
                                                 sortDescriptors: [SortDescriptor(\.startDate)])
        let samples = try await descriptor.result(for: store)
        let asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                                HKCategoryValueSleepAnalysis.asleepREM.rawValue]
        return samples.filter { asleep.contains($0.value) }.map { HealthSleepInterval(start: $0.startDate, end: $0.endDate) }
    }

    private func todayTotal(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double {
        let type = HKQuantityType(identifier)
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: type, predicate: predicate),
                                                     options: .cumulativeSum)
        let stats = try await descriptor.result(for: store)
        return stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    /// Steps and active energy for today, shown on the dashboard.
    func refreshToday() async {
        guard HealthSettings.isEnabled, Self.isAvailable else { return }
        do {
            todaySteps = Int(try await todayTotal(.stepCount, unit: .count()).rounded())
            todayActiveEnergyKcal = try await todayTotal(.activeEnergyBurned, unit: .kilocalorie())
            lastRefresh = .now
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Import into the app's store

    /// Pulls weigh-ins, resting heart rate and sleep since `since` into SwiftData, skipping what is already there.
    @discardableResult
    func importSamples(since: Date, into context: ModelContext) async throws -> HealthImportSummary {
        guard HealthSettings.isEnabled, Self.isAvailable else { return HealthImportSummary() }
        var summary = HealthImportSummary()
        let calendar = Calendar.current

        // Weight
        let existingWeights = try context.fetch(FetchDescriptor<WeightEntry>())
        let knownIDs = Set(existingWeights.compactMap(\.sourceID))
        let weights = try await quantitySamples(.bodyMass, unit: .gramUnit(with: .kilo), since: since)
        for s in HealthImportRules.newSamples(weights, existingIDs: knownIDs) {
            let entry = WeightEntry(date: s.date, weightKg: (s.value * 10).rounded() / 10, note: "From Apple Health")
            entry.sourceID = s.id.uuidString
            context.insert(entry)
            summary.weighIns += 1
        }

        // Resting heart rate and sleep share one Health-sourced vitals entry per day.
        let existingVitals = try context.fetch(FetchDescriptor<VitalsEntry>())
        var healthVitals: [String: VitalsEntry] = [:]
        for v in existingVitals { if let id = v.sourceID { healthVitals[id] = v } }
        func vitalsEntry(for day: Date) -> VitalsEntry {
            let id = HealthImportRules.vitalsSourceID(for: day, calendar: calendar)
            if let existing = healthVitals[id] { return existing }
            let entry = VitalsEntry(date: calendar.date(byAdding: .hour, value: 7, to: day) ?? day)
            entry.sourceID = id
            entry.note = "From Apple Health"
            context.insert(entry)
            healthVitals[id] = entry
            return entry
        }

        let rhr = try await quantitySamples(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), since: since)
        for (day, sample) in HealthImportRules.latestPerDay(rhr, calendar: calendar) {
            let entry = vitalsEntry(for: day)
            let value = Int(sample.value.rounded())
            if entry.restingHeartRate != value {
                entry.restingHeartRate = value
                summary.restingHeartRateDays += 1
            }
        }

        let sleep = try await sleepIntervals(since: since)
        for (night, hours) in HealthImportRules.sleepHoursByNight(sleep, calendar: calendar) where hours >= 1 {
            let entry = vitalsEntry(for: night)
            let rounded = (hours * 10).rounded() / 10
            if entry.sleepHours != rounded {
                entry.sleepHours = rounded
                summary.sleepNights += 1
            }
        }

        // Workouts become exercise entries (active energy only, like the app's own estimates).
        let existingWorkouts = Set(try context.fetch(FetchDescriptor<ExerciseEntry>()).compactMap(\.sourceID))
        let workoutPredicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        let workouts = try await HKSampleQueryDescriptor(predicates: [.workout(workoutPredicate)],
                                                         sortDescriptors: [SortDescriptor(\.startDate)]).result(for: store)
        for workout in workouts where !existingWorkouts.contains(workout.uuid.uuidString) {
            let kcal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            let entry = ExerciseEntry(date: workout.startDate, activity: HealthImportRules.workoutName(workout.workoutActivityType.rawValue),
                                      minutes: (workout.duration / 60).rounded(), calories: kcal.rounded())
            entry.sourceID = workout.uuid.uuidString
            context.insert(entry)
            summary.workouts += 1
        }

        try context.save()
        HealthSettings.lastImport = .now
        return summary
    }

    /// Imports everything new since the last import (or 90 days on first run).
    func importIfDue(into context: ModelContext, force: Bool = false) async -> HealthImportSummary? {
        guard HealthSettings.isEnabled, Self.isAvailable else { return nil }
        let lastImport = HealthSettings.lastImport
        if !force, let lastImport, Date.now.timeIntervalSince(lastImport) < 15 * 60 { return nil }
        let since = lastImport.map { $0.addingTimeInterval(-2 * 86_400) }
            ?? Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .now
        do {
            let summary = try await importSamples(since: since, into: context)
            lastError = nil
            return summary
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: Writes

    /// Saves a weigh-in to Health and returns the sample id so re-imports skip it.
    func saveWeight(kg: Double, date: Date) async throws -> UUID {
        let sample = HKQuantitySample(type: HKQuantityType(.bodyMass),
                                      quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                                      start: date, end: date)
        try await store.save(sample)
        return sample.uuid
    }

    private func dietarySamples(for entry: FoodLogEntry) -> [HKQuantitySample] {
        let metadata: [String: Any] = [HealthImportRules.metadataKey: entry.uuid.uuidString,
                                       HKMetadataKeyFoodType: entry.foodName]
        func sample(_ id: HKQuantityTypeIdentifier, _ value: Double, _ unit: HKUnit) -> HKQuantitySample {
            HKQuantitySample(type: HKQuantityType(id), quantity: HKQuantity(unit: unit, doubleValue: max(value, 0)),
                             start: entry.date, end: entry.date, metadata: metadata)
        }
        return [sample(.dietaryEnergyConsumed, entry.calories, .kilocalorie()),
                sample(.dietaryProtein, entry.protein, .gram()),
                sample(.dietaryCarbohydrates, entry.carbs, .gram()),
                sample(.dietaryFatTotal, entry.fat, .gram())]
    }

    private func deleteDietarySamples(entryID: UUID) async throws {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HealthImportRules.metadataKey,
                                                    allowedValues: [entryID.uuidString])
        for id in [HKQuantityTypeIdentifier.dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal] {
            _ = try await store.deleteObjects(of: HKQuantityType(id), predicate: predicate)
        }
    }

    /// Fire-and-forget: mirrors a diary entry into Health when sync is on.
    func recordDiaryEntry(_ entry: FoodLogEntry) {
        guard HealthSettings.isEnabled, Self.isAvailable, entry.calories > 0 else { return }
        let samples = dietarySamples(for: entry)
        let id = entry.uuid
        Task { @MainActor in
            do {
                try await deleteDietarySamples(entryID: id)
                try await store.save(samples)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func removeDiaryEntry(id: UUID) {
        guard HealthSettings.isEnabled, Self.isAvailable else { return }
        Task { @MainActor in
            do { try await deleteDietarySamples(entryID: id) } catch { lastError = error.localizedDescription }
        }
    }
}

extension ModelContext {
    /// Inserts a diary line and mirrors it to Apple Health when sync is enabled.
    @MainActor
    func insertDiaryEntry(_ entry: FoodLogEntry) {
        insert(entry)
        HealthKitManager.shared.recordDiaryEntry(entry)
    }

    /// Deletes a diary line and its Health samples.
    @MainActor
    func deleteDiaryEntry(_ entry: FoodLogEntry) {
        let id = entry.uuid
        delete(entry)
        HealthKitManager.shared.removeDiaryEntry(id: id)
    }
}
