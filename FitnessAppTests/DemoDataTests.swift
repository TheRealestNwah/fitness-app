import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class DemoDataTests: XCTestCase {
    private func date(hour: Int) throws -> Date {
        try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: hour)))
    }

    private func demo(at now: Date) throws -> ModelContainer {
        let schema = AppStore.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        SeedData.seedIfNeeded(context: container.mainContext)
        DemoData.load(context: container.mainContext, now: now)
        try container.mainContext.save()
        return container
    }

    func testEarlyMorningMeasurementsAreNotInTheFuture() throws {
        for hour in [0, 5] {
            let now = try date(hour: hour)
            let container = try demo(at: now)
            let weights = try container.mainContext.fetch(FetchDescriptor<WeightEntry>())
            let vitals = try container.mainContext.fetch(FetchDescriptor<VitalsEntry>())
            XCTAssertFalse(weights.isEmpty)
            XCTAssertFalse(vitals.isEmpty)
            XCTAssertTrue(weights.allSatisfy { $0.date <= now })
            XCTAssertTrue(vitals.allSatisfy { $0.date <= now })
            XCTAssertEqual(weights.map(\.date).max(), now)
            XCTAssertEqual(vitals.map(\.date).max(), now)
            let plans = try container.mainContext.fetch(FetchDescriptor<MealPlanEntry>())
            XCTAssertTrue(plans.contains { $0.day.startOfDay > now.startOfDay }, "Tomorrow's plan must stay in the future")
        }
    }

    func testNewReadingSortsAboveDemoVitalsBeforeSevenAM() throws {
        let now = try date(hour: 5)
        let container = try demo(at: now)
        let reading = VitalsEntry(date: now.addingTimeInterval(1))
        reading.systolic = 111
        reading.diastolic = 77
        container.mainContext.insert(reading)
        try container.mainContext.save()
        let latest = try container.mainContext.fetch(FetchDescriptor<VitalsEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])).first
        XCTAssertEqual(latest?.uuid, reading.uuid)
    }

    func testAfternoonDemoKeepsTheMorningMeasurementTime() throws {
        let container = try demo(at: date(hour: 13))
        let weights = try container.mainContext.fetch(FetchDescriptor<WeightEntry>())
        let vitals = try container.mainContext.fetch(FetchDescriptor<VitalsEntry>())
        XCTAssertEqual(weights.map(\.date).max(), try date(hour: 7))
        XCTAssertEqual(vitals.map(\.date).max(), try date(hour: 7))
    }
}
