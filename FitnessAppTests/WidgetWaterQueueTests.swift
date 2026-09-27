import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class WidgetWaterQueueTests: XCTestCase {
    // Held so the context stays valid: a ModelContext doesn't keep its container alive.
    private var container: ModelContainer!
    private var context: ModelContext!
    private var defaults: UserDefaults!
    private let suite = "WidgetWaterQueueTests"

    override func setUp() async throws {
        container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        context = container.mainContext
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    private func queue(_ glasses: [WidgetWaterQueue.Pending]) throws {
        defaults.set(try JSONEncoder().encode(glasses), forKey: WidgetWaterQueue.key)
    }

    private func water() throws -> [WaterEntry] {
        try context.fetch(FetchDescriptor<WaterEntry>(sortBy: [SortDescriptor(\.date)]))
    }

    func testDrainAddsQueuedGlassesAndEmptiesQueue() throws {
        let first = WidgetWaterQueue.Pending(id: UUID(), date: Date(timeIntervalSince1970: 1_800_000_000), ml: 250)
        let second = WidgetWaterQueue.Pending(id: UUID(), date: Date(timeIntervalSince1970: 1_800_003_600), ml: 236.6)
        try queue([first, second])
        XCTAssertEqual(WidgetWaterQueue.drain(into: context, defaults: defaults), 2)
        let entries = try water()
        XCTAssertEqual(entries.map(\.uuid), [first.id, second.id])
        XCTAssertEqual(entries.map(\.amountMl), [250, 236.6])
        XCTAssertTrue(WidgetWaterQueue.pending(in: defaults).isEmpty)
    }

    func testDrainSkipsGlassesAlreadyRecorded() throws {
        let glass = WidgetWaterQueue.Pending(id: UUID(), date: .now, ml: 250)
        try queue([glass])
        WidgetWaterQueue.drain(into: context, defaults: defaults)
        try queue([glass])
        XCTAssertEqual(WidgetWaterQueue.drain(into: context, defaults: defaults), 0)
        XCTAssertEqual(try water().count, 1)
    }

    func testDrainIgnoresImplausibleAmounts() throws {
        try queue([.init(id: UUID(), date: .now, ml: 0), .init(id: UUID(), date: .now, ml: 9000)])
        XCTAssertEqual(WidgetWaterQueue.drain(into: context, defaults: defaults), 0)
        XCTAssertTrue(try water().isEmpty)
    }

    func testEmptyOrCorruptQueueIsHarmless() {
        XCTAssertEqual(WidgetWaterQueue.drain(into: context, defaults: defaults), 0)
        defaults.set(Data("nope".utf8), forKey: WidgetWaterQueue.key)
        XCTAssertEqual(WidgetWaterQueue.drain(into: context, defaults: defaults), 0)
    }

    func testSnapshotCarriesGlassSize() {
        let profile = UserProfile(name: "Sam", sex: .female, birthDate: Date(timeIntervalSince1970: 0), heightCm: 168,
                                  startWeightKg: 80, goalWeightKg: 70, activityLevel: .light, weeklyLossKg: 0.5,
                                  unitSystem: .imperial)
        let snapshot = WidgetSnapshot.make(profile: profile, food: [], water: [], latestWeightKg: nil, logDates: [])
        XCTAssertEqual(snapshot.glassMl ?? 0, 236.6, accuracy: 0.01)
    }
}
