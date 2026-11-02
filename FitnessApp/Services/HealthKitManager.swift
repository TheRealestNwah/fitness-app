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

/// What onboarding can fill in from Apple Health; each part is nil when Health has nothing.
struct HealthProfileDetails: Equatable {
    var birthDate: Date?
    var sex: BiologicalSex?
    var heightCm: Double?
    var weightKg: Double?

    var isEmpty: Bool { birthDate == nil && sex == nil && heightCm == nil && weightKg == nil }

    /// Health's sex, when it's one the calorie formula uses.
    static func sex(_ value: HKBiologicalSex) -> BiologicalSex? {
        switch value {
        case .female: .female
        case .male: .male
        default: nil
        }
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
        if weighIns > 0 { parts.append(String(localized: "\(weighIns) weigh-ins")) }
        if restingHeartRateDays > 0 { parts.append(String(localized: "\(restingHeartRateDays) resting heart rates")) }
        if sleepNights > 0 { parts.append(String(localized: "\(sleepNights) nights of sleep")) }
        if workouts > 0 { parts.append(String(localized: "\(workouts) workouts")) }
        return parts.isEmpty ? String(localized: "Nothing new to import")
                             : String(localized: "Imported \(parts.joined(separator: ", "))")
    }
}

/// Pure helpers so the import rules can be unit-tested without HealthKit.
enum HealthImportRules {
    static let metadataKey = "StrideEntryID"

    /// Nutrient types a diary entry is written to Health as.
    static let dietaryTypes: [HKQuantityTypeIdentifier] = [.dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates,
                                                           .dietaryFatTotal, .dietaryFiber, .dietarySugar, .dietarySodium,
                                                           .dietaryFatSaturated, .dietaryPotassium, .dietaryCholesterol,
                                                           .dietaryCaffeine, .numberOfAlcoholicBeverages]
        + Micronutrient.allCases.map(\.healthIdentifier)

    /// What a diary entry is written to Health as. Energy and macros are always written;
    /// fibre, sugar and sodium only when recorded, since zero usually means unknown.
    static func dietaryValues(calories: Double, protein: Double, carbs: Double, fat: Double,
                              fiber: Double, sugar: Double, sodiumMg: Double,
                              saturatedFat: Double = 0, potassiumMg: Double = 0,
                              cholesterolMg: Double = 0, alcoholG: Double = 0,
                              caffeineMg: Double = 0,
                              micros: Micronutrients = Micronutrients()) -> [(type: HKQuantityTypeIdentifier, value: Double, unit: HKUnit)] {
        var values: [(type: HKQuantityTypeIdentifier, value: Double, unit: HKUnit)] = [
            (.dietaryEnergyConsumed, max(calories, 0), .kilocalorie()),
            (.dietaryProtein, max(protein, 0), .gram()),
            (.dietaryCarbohydrates, max(carbs, 0), .gram()),
            (.dietaryFatTotal, max(fat, 0), .gram()),
        ]
        if fiber > 0 { values.append((.dietaryFiber, fiber, .gram())) }
        if sugar > 0 { values.append((.dietarySugar, sugar, .gram())) }
        if sodiumMg > 0 { values.append((.dietarySodium, sodiumMg, .gramUnit(with: .milli))) }
        if saturatedFat > 0 { values.append((.dietaryFatSaturated, saturatedFat, .gram())) }
        if potassiumMg > 0 { values.append((.dietaryPotassium, potassiumMg, .gramUnit(with: .milli))) }
        if cholesterolMg > 0 { values.append((.dietaryCholesterol, cholesterolMg, .gramUnit(with: .milli))) }
        if caffeineMg > 0 { values.append((.dietaryCaffeine, caffeineMg, .gramUnit(with: .milli))) }
        for nutrient in Micronutrient.allCases where micros[nutrient] > 0 {
            values.append((nutrient.healthIdentifier, micros[nutrient],
                           .gramUnit(with: nutrient.unit == "mg" ? .milli : .micro)))
        }
        // Health counts alcohol as standard drinks rather than grams.
        if alcoholG > 0 { values.append((.numberOfAlcoholicBeverages, Alcohol.standardDrinks(grams: alcoholG), .count())) }
        return values
    }

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

/// Apple Health as the rest of the app sees it: today's activity, cycle-based retention days,
/// importing into the store and mirroring diary, water and weight entries out.
/// All HealthKit calls go through a `HealthStore`, so tests can run it against a fake (ADR 0011).
@MainActor
@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store: HealthStore
    private let defaults: UserDefaults
    private let now: () -> Date

    var todaySteps: Int = 0
    var todayActiveEnergyKcal: Double = 0
    var lastRefresh: Date?
    var lastError: String?
    /// Likely water-retention days from cycle data, when cycle-aware weight is on.
    var retentionDays: Set<Date> = []

    init(store: HealthStore = HealthKitStore(), defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.store = store
        self.defaults = defaults
        self.now = now
    }

    static var isAvailable: Bool { shared.isAvailable }
    var isAvailable: Bool { store.isAvailable }

    private var isEnabled: Bool { defaults.bool(forKey: HealthSettings.enabledKey) }
    private var isOn: Bool { isEnabled && isAvailable }

    /// Calories added to today's budget from active energy, per the user's chosen share.
    var activeEnergyCredit: Int {
        guard isEnabled else { return 0 }
        return HealthImportRules.activeEnergyCredit(activeKcal: todayActiveEnergyKcal,
                                                    percent: defaults.integer(forKey: HealthSettings.creditPercentKey))
    }

    // MARK: Authorization

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }
        try await store.requestAuthorization()
    }

    /// Asks again only when there are types the user hasn't been asked about yet, such as ones
    /// added in an update. Health shows just the new ones.
    func requestNewTypesIfNeeded() async {
        guard isOn, await store.hasUnrequestedTypes() else { return }
        try? await requestAuthorization()
    }

    // MARK: Reads

    /// Asks for read access to the profile basics and returns whatever Health has.
    /// Denied or missing items come back nil (Health doesn't say which were denied).
    func profileDetails() async throws -> HealthProfileDetails {
        guard isAvailable else { throw HealthKitError.unavailable }
        return try await store.profileDetails()
    }

    /// Steps and active energy for today, shown on the dashboard.
    func refreshToday() async {
        guard isOn else { return }
        let start = Calendar.current.startOfDay(for: now())
        do {
            todaySteps = Int(try await store.total(.steps, since: start).rounded())
            todayActiveEnergyKcal = try await store.total(.activeEnergy, since: start)
            lastRefresh = now()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Steps and active energy for each of the last `days` days, oldest first, today included.
    func dailyActivity(days: Int) async -> [ActivityDay] {
        guard isOn else { return [] }
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: now())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: end),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: end) else { return [] }
        let health = store
        async let steps = health.dailySums(.steps, from: start, to: tomorrow)
        async let energy = health.dailySums(.activeEnergy, from: start, to: tomorrow)
        let (stepSums, energySums) = await (steps, energy)
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return ActivityDay(date: day, steps: Int((stepSums[day] ?? 0).rounded()), activeKcal: energySums[day] ?? 0)
        }
    }

    // MARK: Cycle

    func requestCycleAccess() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }
        try await store.requestCycleAccess()
    }

    /// Reads six months of menstrual flow and works out likely retention days.
    func refreshCycle() async {
        guard defaults.bool(forKey: CycleCalculator.enabledKey), isAvailable else {
            retentionDays = []
            return
        }
        let since = Calendar.current.date(byAdding: .day, value: -180, to: now()) ?? now()
        guard let flowDays = try? await store.menstrualFlowDays(since: since) else { return }
        retentionDays = CycleCalculator.retentionDays(periodStarts: CycleCalculator.periodStarts(flowDays: flowDays),
                                                      today: now())
    }

    // MARK: Import into the app's store

    /// Pulls weigh-ins, resting heart rate, sleep and workouts since `since` into SwiftData,
    /// skipping what is already there.
    @discardableResult
    func importSamples(since: Date, into context: ModelContext) async throws -> HealthImportSummary {
        guard isOn else { return HealthImportSummary() }
        var summary = HealthImportSummary()
        let calendar = Calendar.current

        // Weight
        let existingWeights = try context.fetch(FetchDescriptor<WeightEntry>())
        // Weigh-ins deleted in Stride stay deleted.
        let knownIDs = Set(existingWeights.compactMap(\.sourceID)).union(HealthDismissals.ids(.weight, defaults: defaults))
        let weights = try await store.samples(.bodyMass, since: since)
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

        let rhr = try await store.samples(.restingHeartRate, since: since)
        for (day, sample) in HealthImportRules.latestPerDay(rhr, calendar: calendar) {
            let entry = vitalsEntry(for: day)
            let value = Int(sample.value.rounded())
            if entry.restingHeartRate != value {
                entry.restingHeartRate = value
                summary.restingHeartRateDays += 1
            }
        }

        let sleep = try await store.sleepIntervals(since: since)
        for (night, hours) in HealthImportRules.sleepHoursByNight(sleep, calendar: calendar) where hours >= 1 {
            let entry = vitalsEntry(for: night)
            let rounded = (hours * 10).rounded() / 10
            if entry.sleepHours != rounded {
                entry.sleepHours = rounded
                summary.sleepNights += 1
            }
        }

        // Workouts become exercise entries (active energy only, like the app's own estimates).
        summary.workouts = try await HealthWorkoutImporter.importSamples(into: context, defaults: defaults) { [store] in
            try await store.workouts(since: since)
        }

        try context.save()
        defaults.set(now(), forKey: HealthSettings.lastImportKey)
        return summary
    }

    /// Imports everything new since the last import (or 90 days on first run).
    func importIfDue(into context: ModelContext, force: Bool = false) async -> HealthImportSummary? {
        guard isOn else { return nil }
        let current = now()
        let lastImport = defaults.object(forKey: HealthSettings.lastImportKey) as? Date
        if !force, let lastImport, current.timeIntervalSince(lastImport) < 15 * 60 { return nil }
        let since = lastImport.map { $0.addingTimeInterval(-2 * 86_400) }
            ?? Calendar.current.date(byAdding: .day, value: -90, to: current) ?? current
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
        try await store.saveWeight(kg: kg, date: date)
    }

    /// Fire-and-forget: mirrors a diary entry into Health when sync is on.
    /// Returns the write so tests can wait for it; nil when nothing is written.
    @discardableResult
    func recordDiaryEntry(_ entry: FoodLogEntry) -> Task<Void, Never>? {
        // Zero-calorie drinks still count for their caffeine.
        guard isOn, entry.calories > 0 || entry.caffeine > 0 else { return nil }
        let record = DietaryHealthRecord(entry)
        return write { try await $0.replaceDietarySamples(record) }
    }

    @discardableResult
    func removeDiaryEntry(id: UUID) -> Task<Void, Never>? {
        guard isOn else { return nil }
        return write { try await $0.deleteDietarySamples(entryID: id) }
    }

    /// Fire-and-forget: mirrors a glass of water into Health when sync is on.
    @discardableResult
    func recordWater(_ entry: WaterEntry) -> Task<Void, Never>? {
        guard isOn, entry.amountMl > 0 else { return nil }
        let (ml, date, id) = (entry.amountMl, entry.date, entry.uuid)
        return write { try await $0.saveWater(ml: ml, date: date, entryID: id) }
    }

    @discardableResult
    func removeWater(id: UUID) -> Task<Void, Never>? {
        guard isOn else { return nil }
        return write { try await $0.deleteWater(entryID: id) }
    }

    /// Runs a write in the background, keeping its error for Settings to show.
    private func write(_ operation: @escaping @MainActor (HealthStore) async throws -> Void) -> Task<Void, Never> {
        let health = store
        return Task { @MainActor in
            do { try await operation(health) } catch { lastError = error.localizedDescription }
        }
    }
}

extension ModelContext {
    /// Inserts a glass of water and mirrors it to Apple Health when sync is enabled.
    @MainActor
    func insertWater(_ entry: WaterEntry) {
        insert(entry)
        HealthKitManager.shared.recordWater(entry)
    }

    /// Deletes a water entry and its Health sample.
    @MainActor
    func deleteWater(_ entry: WaterEntry) {
        let id = entry.uuid
        delete(entry)
        HealthKitManager.shared.removeWater(id: id)
    }
}
