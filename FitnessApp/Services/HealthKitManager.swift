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

    /// What a diary entry is written to Health as. Energy and macros are always written;
    /// fibre, sugar and sodium only when recorded, since zero usually means unknown.
    static func dietaryValues(calories: Double, protein: Double, carbs: Double, fat: Double,
                              fiber: Double, sugar: Double, sodiumMg: Double,
                              saturatedFat: Double = 0, potassiumMg: Double = 0,
                              cholesterolMg: Double = 0, alcoholG: Double = 0,
                              caffeineMg: Double = 0) -> [(type: HKQuantityTypeIdentifier, value: Double, unit: HKUnit)] {
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

@MainActor
@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    @ObservationIgnored private lazy var store = HKHealthStore()

    var todaySteps: Int = 0
    var todayActiveEnergyKcal: Double = 0
    var lastRefresh: Date?
    var lastError: String?
    /// Likely water-retention days from cycle data, when cycle-aware weight is on.
    var retentionDays: Set<Date> = []

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Calories added to today's budget from active energy, per the user's chosen share.
    var activeEnergyCredit: Int {
        guard HealthSettings.isEnabled else { return 0 }
        return HealthImportRules.activeEnergyCredit(activeKcal: todayActiveEnergyKcal, percent: HealthSettings.creditPercent)
    }

    private var readTypes: Set<HKObjectType> {
        let sync: Set<HKObjectType> = [HKQuantityType(.bodyMass), HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned),
                                       HKQuantityType(.restingHeartRate), HKCategoryType(.sleepAnalysis), HKObjectType.workoutType()]
        return sync.union(profileTypes)
    }

    /// Read during setup to fill in the profile.
    private var profileTypes: Set<HKObjectType> {
        [HKCharacteristicType(.dateOfBirth), HKCharacteristicType(.biologicalSex),
         HKQuantityType(.height), HKQuantityType(.bodyMass)]
    }

    private var writeTypes: Set<HKSampleType> {
        Set([HKQuantityType(.bodyMass), HKQuantityType(.dietaryWater)] + HealthImportRules.dietaryTypes.map { HKQuantityType($0) })
    }

    // MARK: Authorization

    func requestAuthorization() async throws {
        guard Self.isAvailable else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    /// Asks again only when there are types the user hasn't been asked about yet, such as ones
    /// added in an update. Health shows just the new ones.
    func requestNewTypesIfNeeded() async {
        guard HealthSettings.isEnabled, Self.isAvailable,
              (try? await store.statusForAuthorizationRequest(toShare: writeTypes, read: readTypes)) == .shouldRequest
        else { return }
        try? await requestAuthorization()
    }

    /// Writing or deleting a type the user hasn't allowed fails the whole call, so each is checked.
    private func canShare(_ type: HKObjectType) -> Bool {
        store.authorizationStatus(for: type) == .sharingAuthorized
    }

    // MARK: Reads

    /// Asks for read access to the profile basics and returns whatever Health has.
    /// Denied or missing items come back nil (Health doesn't say which were denied).
    func profileDetails() async throws -> HealthProfileDetails {
        guard Self.isAvailable else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: [], read: profileTypes)
        var details = HealthProfileDetails()
        if let components = try? store.dateOfBirthComponents() {
            details.birthDate = Calendar.current.date(from: components)
        }
        if let sex = try? store.biologicalSex().biologicalSex {
            details.sex = HealthProfileDetails.sex(sex)
        }
        details.heightCm = try? await latestValue(.height, unit: .meterUnit(with: .centi))
        details.weightKg = try? await latestValue(.bodyMass, unit: .gramUnit(with: .kilo))
        return details
    }

    private func latestValue(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: HKQuantityType(identifier))],
                                                 sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                                                 limit: 1)
        return try await descriptor.result(for: store).first?.quantity.doubleValue(for: unit)
    }

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

    /// Steps and active energy for each of the last `days` days, oldest first, today included.
    func dailyActivity(days: Int) async -> [ActivityDay] {
        guard HealthSettings.isEnabled, Self.isAvailable else { return [] }
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: end),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: end) else { return [] }
        async let steps = dailySums(.stepCount, unit: .count(), from: start, to: tomorrow)
        async let energy = dailySums(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: tomorrow)
        let (stepSums, energySums) = await (steps, energy)
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return ActivityDay(date: day, steps: Int((stepSums[day] ?? 0).rounded()), activeKcal: energySums[day] ?? 0)
        }
    }

    private func dailySums(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(identifier), predicate: predicate),
            options: .cumulativeSum, anchorDate: start, intervalComponents: DateComponents(day: 1))
        guard let collection = try? await descriptor.result(for: store) else { return [:] }
        var sums: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            sums[stats.startDate] = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
        }
        return sums
    }

    // MARK: Cycle

    func requestCycleAccess() async throws {
        guard Self.isAvailable else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: [], read: [HKCategoryType(.menstrualFlow)])
    }

    /// Reads six months of menstrual flow and works out likely retention days.
    func refreshCycle() async {
        guard CycleCalculator.isEnabled, Self.isAvailable else {
            retentionDays = []
            return
        }
        let since = Calendar.current.date(byAdding: .day, value: -180, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.menstrualFlow), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        guard let samples = try? await descriptor.result(for: store) else { return }
        // Raw value 5 is "no flow" (HKCategoryValueMenstrualFlow.none), logged on some days.
        let flowDays = samples.filter { $0.value != 5 }.map(\.startDate)
        retentionDays = CycleCalculator.retentionDays(periodStarts: CycleCalculator.periodStarts(flowDays: flowDays))
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
        // Weigh-ins deleted in Stride stay deleted.
        let knownIDs = Set(existingWeights.compactMap(\.sourceID)).union(HealthDismissals.ids(.weight))
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
        let workoutPredicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        summary.workouts = try await HealthWorkoutImporter.importSamples(into: context) {
            let workouts = try await HKSampleQueryDescriptor(predicates: [.workout(workoutPredicate)],
                                                             sortDescriptors: [SortDescriptor(\.startDate)]).result(for: self.store)
            return workouts.map { workout in
                HealthWorkoutSample(id: workout.uuid, date: workout.startDate,
                                    activity: HealthImportRules.workoutName(workout.workoutActivityType.rawValue),
                                    duration: workout.duration,
                                    activeCalories: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                                        .sumQuantity()?.doubleValue(for: .kilocalorie()))
            }
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
        return HealthImportRules.dietaryValues(calories: entry.calories, protein: entry.protein, carbs: entry.carbs,
                                               fat: entry.fat, fiber: entry.fiber, sugar: entry.sugar, sodiumMg: entry.sodium,
                                               saturatedFat: entry.saturatedFat, potassiumMg: entry.potassium,
                                               cholesterolMg: entry.cholesterol, alcoholG: entry.alcohol,
                                               caffeineMg: entry.caffeine)
            .map { HKQuantitySample(type: HKQuantityType($0.type), quantity: HKQuantity(unit: $0.unit, doubleValue: $0.value),
                                    start: entry.date, end: entry.date, metadata: metadata) }
    }

    private func deleteDietarySamples(entryID: UUID) async throws {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HealthImportRules.metadataKey,
                                                    allowedValues: [entryID.uuidString])
        for id in HealthImportRules.dietaryTypes where canShare(HKQuantityType(id)) {
            _ = try await store.deleteObjects(of: HKQuantityType(id), predicate: predicate)
        }
    }

    /// Fire-and-forget: mirrors a diary entry into Health when sync is on.
    func recordDiaryEntry(_ entry: FoodLogEntry) {
        // Zero-calorie drinks still count for their caffeine.
        guard HealthSettings.isEnabled, Self.isAvailable, entry.calories > 0 || entry.caffeine > 0 else { return }
        let samples = dietarySamples(for: entry).filter { canShare($0.sampleType) }
        let id = entry.uuid
        Task { @MainActor in
            do {
                try await deleteDietarySamples(entryID: id)
                if !samples.isEmpty { try await store.save(samples) }
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

    /// Fire-and-forget: mirrors a glass of water into Health when sync is on.
    func recordWater(_ entry: WaterEntry) {
        guard HealthSettings.isEnabled, Self.isAvailable, entry.amountMl > 0 else { return }
        let sample = HKQuantitySample(type: HKQuantityType(.dietaryWater),
                                      quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: entry.amountMl),
                                      start: entry.date, end: entry.date,
                                      metadata: [HealthImportRules.metadataKey: entry.uuid.uuidString])
        Task { @MainActor in
            do { try await store.save(sample) } catch { lastError = error.localizedDescription }
        }
    }

    func removeWater(id: UUID) {
        guard HealthSettings.isEnabled, Self.isAvailable else { return }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HealthImportRules.metadataKey,
                                                    allowedValues: [id.uuidString])
        Task { @MainActor in
            do { _ = try await store.deleteObjects(of: HKQuantityType(.dietaryWater), predicate: predicate) }
            catch { lastError = error.localizedDescription }
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
