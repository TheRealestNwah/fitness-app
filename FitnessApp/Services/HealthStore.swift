import Foundation
import HealthKit

/// A Health reading Stride asks for by amount, each in one fixed unit.
enum HealthQuantity: CaseIterable {
    /// Kilograms.
    case bodyMass
    /// Centimetres.
    case height
    /// Beats per minute.
    case restingHeartRate
    /// Count.
    case steps
    /// Kilocalories.
    case activeEnergy
}

/// A diary entry as it's written to Health: one sample per nutrient, all tagged with the entry's id.
struct DietaryHealthRecord {
    var entryID: UUID
    var date: Date
    var foodName: String
    var values: [(type: HKQuantityTypeIdentifier, value: Double, unit: HKUnit)]

    init(_ entry: FoodLogEntry) {
        entryID = entry.uuid
        date = entry.date
        foodName = entry.foodName
        values = HealthImportRules.dietaryValues(calories: entry.calories, protein: entry.protein, carbs: entry.carbs,
                                                 fat: entry.fat, fiber: entry.fiber, sugar: entry.sugar,
                                                 sodiumMg: entry.sodium, saturatedFat: entry.saturatedFat,
                                                 potassiumMg: entry.potassium, cholesterolMg: entry.cholesterol,
                                                 alcoholG: entry.alcohol, caffeineMg: entry.caffeine,
                                                 micros: entry.micros)
    }
}

/// Everything Stride reads from or writes to Apple Health, in plain values.
///
/// `HealthKitManager` holds the rules (what to import, when, and what it adds to the budget) and
/// talks to Health only through this. The app uses `HealthKitStore`; tests use `FakeHealthStore`.
/// See ADR 0011.
@MainActor
protocol HealthStore: AnyObject, Sendable {
    /// Whether this device has Apple Health at all (false on iPad without Health, and on Mac).
    var isAvailable: Bool { get }

    // MARK: Access

    /// Asks for everything Stride reads and writes.
    func requestAuthorization() async throws
    /// True when there are types the person hasn't been asked about yet, such as ones added in an update.
    func hasUnrequestedTypes() async -> Bool
    func requestCycleAccess() async throws

    // MARK: Reads

    /// Asks for the profile basics and returns whatever Health has; denied or missing items are nil.
    func profileDetails() async throws -> HealthProfileDetails
    /// The sum of a cumulative quantity (steps, active energy) from `start` until now.
    func total(_ quantity: HealthQuantity, since start: Date) async throws -> Double
    /// Daily sums of a cumulative quantity, keyed by the start of each day in `start..<end`.
    /// Empty when Health can't answer.
    func dailySums(_ quantity: HealthQuantity, from start: Date, to end: Date) async -> [Date: Double]
    /// Individual readings (weight, resting heart rate) since `since`, oldest first.
    func samples(_ quantity: HealthQuantity, since: Date) async throws -> [HealthQuantitySample]
    /// Time asleep (any stage) since `since`, oldest first.
    func sleepIntervals(since: Date) async throws -> [HealthSleepInterval]
    /// Days with menstrual flow logged since `since`, leaving out days logged as "no flow".
    func menstrualFlowDays(since: Date) async throws -> [Date]
    /// Workouts that started since `since`, oldest first.
    func workouts(since: Date) async throws -> [HealthWorkoutSample]

    // MARK: Writes

    /// Saves a weigh-in and returns the sample's id.
    func saveWeight(kg: Double, date: Date) async throws -> UUID
    /// Replaces whatever Health has for the diary entry with these values. Types the person
    /// hasn't allowed are skipped, since one disallowed type fails the whole call.
    func replaceDietarySamples(_ record: DietaryHealthRecord) async throws
    func deleteDietarySamples(entryID: UUID) async throws
    func saveWater(ml: Double, date: Date, entryID: UUID) async throws
    func deleteWater(entryID: UUID) async throws
}

/// `HealthStore` backed by HealthKit.
@MainActor
final class HealthKitStore: HealthStore {
    private lazy var store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

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

    private static func identifier(_ quantity: HealthQuantity) -> HKQuantityTypeIdentifier {
        switch quantity {
        case .bodyMass: .bodyMass
        case .height: .height
        case .restingHeartRate: .restingHeartRate
        case .steps: .stepCount
        case .activeEnergy: .activeEnergyBurned
        }
    }

    private static func unit(_ quantity: HealthQuantity) -> HKUnit {
        switch quantity {
        case .bodyMass: .gramUnit(with: .kilo)
        case .height: .meterUnit(with: .centi)
        case .restingHeartRate: HKUnit.count().unitDivided(by: .minute())
        case .steps: .count()
        case .activeEnergy: .kilocalorie()
        }
    }

    /// Writing or deleting a type the user hasn't allowed fails the whole call, so each is checked.
    private func canShare(_ type: HKObjectType) -> Bool {
        store.authorizationStatus(for: type) == .sharingAuthorized
    }

    // MARK: Access

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    func hasUnrequestedTypes() async -> Bool {
        (try? await store.statusForAuthorizationRequest(toShare: writeTypes, read: readTypes)) == .shouldRequest
    }

    func requestCycleAccess() async throws {
        try await store.requestAuthorization(toShare: [], read: [HKCategoryType(.menstrualFlow)])
    }

    // MARK: Reads

    func profileDetails() async throws -> HealthProfileDetails {
        try await store.requestAuthorization(toShare: [], read: profileTypes)
        var details = HealthProfileDetails()
        if let components = try? store.dateOfBirthComponents() {
            details.birthDate = Calendar.current.date(from: components)
        }
        if let sex = try? store.biologicalSex().biologicalSex {
            details.sex = HealthProfileDetails.sex(sex)
        }
        details.heightCm = try? await latestValue(.height)
        details.weightKg = try? await latestValue(.bodyMass)
        return details
    }

    private func latestValue(_ quantity: HealthQuantity) async throws -> Double? {
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: HKQuantityType(Self.identifier(quantity)))],
                                                 sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                                                 limit: 1)
        return try await descriptor.result(for: store).first?.quantity.doubleValue(for: Self.unit(quantity))
    }

    func total(_ quantity: HealthQuantity, since start: Date) async throws -> Double {
        let type = HKQuantityType(Self.identifier(quantity))
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: type, predicate: predicate),
                                                     options: .cumulativeSum)
        let stats = try await descriptor.result(for: store)
        return stats?.sumQuantity()?.doubleValue(for: Self.unit(quantity)) ?? 0
    }

    func dailySums(_ quantity: HealthQuantity, from start: Date, to end: Date) async -> [Date: Double] {
        let unit = Self.unit(quantity)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(Self.identifier(quantity)), predicate: predicate),
            options: .cumulativeSum, anchorDate: start, intervalComponents: DateComponents(day: 1))
        guard let collection = try? await descriptor.result(for: store) else { return [:] }
        var sums: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            sums[stats.startDate] = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
        }
        return sums
    }

    func samples(_ quantity: HealthQuantity, since: Date) async throws -> [HealthQuantitySample] {
        let type = HKQuantityType(Self.identifier(quantity))
        let unit = Self.unit(quantity)
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

    func sleepIntervals(since: Date) async throws -> [HealthSleepInterval] {
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

    func menstrualFlowDays(since: Date) async throws -> [Date] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.menstrualFlow), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let samples = try await descriptor.result(for: store)
        // Raw value 5 is "no flow" (HKCategoryValueMenstrualFlow.none), logged on some days.
        return samples.filter { $0.value != 5 }.map(\.startDate)
    }

    func workouts(since: Date) async throws -> [HealthWorkoutSample] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        let workouts = try await HKSampleQueryDescriptor(predicates: [.workout(predicate)],
                                                         sortDescriptors: [SortDescriptor(\.startDate)]).result(for: store)
        return workouts.map { workout in
            HealthWorkoutSample(id: workout.uuid, date: workout.startDate,
                                activity: HealthImportRules.workoutName(workout.workoutActivityType.rawValue),
                                duration: workout.duration,
                                activeCalories: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                                    .sumQuantity()?.doubleValue(for: .kilocalorie()))
        }
    }

    // MARK: Writes

    func saveWeight(kg: Double, date: Date) async throws -> UUID {
        let sample = HKQuantitySample(type: HKQuantityType(.bodyMass),
                                      quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                                      start: date, end: date)
        try await store.save(sample)
        return sample.uuid
    }

    func replaceDietarySamples(_ record: DietaryHealthRecord) async throws {
        let metadata: [String: Any] = [HealthImportRules.metadataKey: record.entryID.uuidString,
                                       HKMetadataKeyFoodType: record.foodName]
        let samples = record.values
            .map { HKQuantitySample(type: HKQuantityType($0.type), quantity: HKQuantity(unit: $0.unit, doubleValue: $0.value),
                                    start: record.date, end: record.date, metadata: metadata) }
            .filter { canShare($0.sampleType) }
        try await deleteDietarySamples(entryID: record.entryID)
        if !samples.isEmpty { try await store.save(samples) }
    }

    func deleteDietarySamples(entryID: UUID) async throws {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HealthImportRules.metadataKey,
                                                    allowedValues: [entryID.uuidString])
        for id in HealthImportRules.dietaryTypes where canShare(HKQuantityType(id)) {
            _ = try await store.deleteObjects(of: HKQuantityType(id), predicate: predicate)
        }
    }

    func saveWater(ml: Double, date: Date, entryID: UUID) async throws {
        let sample = HKQuantitySample(type: HKQuantityType(.dietaryWater),
                                      quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml),
                                      start: date, end: date,
                                      metadata: [HealthImportRules.metadataKey: entryID.uuidString])
        try await store.save(sample)
    }

    func deleteWater(entryID: UUID) async throws {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HealthImportRules.metadataKey,
                                                    allowedValues: [entryID.uuidString])
        _ = try await store.deleteObjects(of: HKQuantityType(.dietaryWater), predicate: predicate)
    }
}
