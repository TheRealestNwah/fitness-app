import Foundation
@testable import FitnessApp

/// An in-memory `HealthStore`: returns whatever a test puts in it and records what was written.
@MainActor
final class FakeHealthStore: HealthStore {
    struct Failure: LocalizedError {
        var errorDescription: String? { "Health said no" }
    }

    var isAvailable = true
    /// Thrown by every throwing call when set.
    var error: Error?

    var unrequestedTypes = false
    var profile = HealthProfileDetails()
    var totals: [HealthQuantity: Double] = [:]
    var daily: [HealthQuantity: [Date: Double]] = [:]
    var readings: [HealthQuantity: [HealthQuantitySample]] = [:]
    var sleep: [HealthSleepInterval] = []
    var flowDays: [Date] = []
    var workoutSamples: [HealthWorkoutSample] = []

    private(set) var authorizationRequests = 0
    private(set) var cycleAccessRequests = 0
    private(set) var readSince: [Date] = []
    private(set) var savedWeights: [(kg: Double, date: Date, id: UUID)] = []
    /// Dietary samples Health holds, by diary entry id.
    private(set) var dietary: [UUID: DietaryHealthRecord] = [:]
    /// Water Health holds, by water entry id.
    private(set) var water: [UUID: Double] = [:]

    private func check() throws {
        if let error { throw error }
    }

    func requestAuthorization() async throws {
        try check()
        authorizationRequests += 1
        unrequestedTypes = false
    }

    func hasUnrequestedTypes() async -> Bool { unrequestedTypes }

    func requestCycleAccess() async throws {
        try check()
        cycleAccessRequests += 1
    }

    func profileDetails() async throws -> HealthProfileDetails {
        try check()
        return profile
    }

    func total(_ quantity: HealthQuantity, since start: Date) async throws -> Double {
        try check()
        return totals[quantity] ?? 0
    }

    func dailySums(_ quantity: HealthQuantity, from start: Date, to end: Date) async -> [Date: Double] {
        (daily[quantity] ?? [:]).filter { $0.key >= start && $0.key < end }
    }

    func samples(_ quantity: HealthQuantity, since: Date) async throws -> [HealthQuantitySample] {
        try check()
        readSince.append(since)
        return (readings[quantity] ?? []).filter { $0.date >= since }
    }

    func sleepIntervals(since: Date) async throws -> [HealthSleepInterval] {
        try check()
        return sleep.filter { $0.start >= since }
    }

    func menstrualFlowDays(since: Date) async throws -> [Date] {
        try check()
        return flowDays.filter { $0 >= since }
    }

    func workouts(since: Date) async throws -> [HealthWorkoutSample] {
        try check()
        return workoutSamples.filter { $0.date >= since }
    }

    func saveWeight(kg: Double, date: Date) async throws -> UUID {
        try check()
        let id = UUID()
        savedWeights.append((kg, date, id))
        return id
    }

    func replaceDietarySamples(_ record: DietaryHealthRecord) async throws {
        try check()
        dietary[record.entryID] = record
    }

    func deleteDietarySamples(entryID: UUID) async throws {
        try check()
        dietary[entryID] = nil
    }

    func saveWater(ml: Double, date: Date, entryID: UUID) async throws {
        try check()
        water[entryID] = ml
    }

    func deleteWater(entryID: UUID) async throws {
        try check()
        water[entryID] = nil
    }
}
