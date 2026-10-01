import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class HealthWorkoutImporterTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let date = Date(timeIntervalSinceReferenceDate: 800_000_000)

    override func setUp() async throws {
        container = try ModelContainer(for: ExerciseEntry.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = container.mainContext
    }

    private func sample(calories: Double? = 180) -> HealthWorkoutSample {
        HealthWorkoutSample(id: UUID(), date: date, activity: "Walking", duration: 1800, activeCalories: calories)
    }

    private func entries() throws -> [ExerciseEntry] {
        try context.fetch(FetchDescriptor<ExerciseEntry>())
    }

    func testSaveDuringHealthQueryKeepsTheRecordedWorkoutAndItsEstimate() async throws {
        let workout = sample(calories: nil)
        let recorded = ExerciseEntry(date: date, activity: "Morning walk", minutes: 31, calories: 175)
        recorded.sourceID = workout.id.uuidString

        let imported = try await HealthWorkoutImporter.importSamples(into: context) {
            await Task.yield()
            // Simulate the recording flow saving while the Health query is in flight.
            self.context.insert(recorded)
            try self.context.save()
            return [workout]
        }

        XCTAssertEqual(imported, 0)
        let all = try entries()
        XCTAssertEqual(all.count, 1)
        let entry = try XCTUnwrap(all.first)
        XCTAssertEqual(entry.uuid, recorded.uuid)
        XCTAssertEqual(entry.activity, "Morning walk")
        XCTAssertEqual(entry.minutes, 31)
        XCTAssertEqual(entry.calories, 175)
        XCTAssertEqual(entry.date, date)
    }

    func testOverlappingImportsAndARepeatInsertTheWorkoutOnlyOnce() async throws {
        let workout = sample()
        var innerCount = 0
        let outerCount = try await HealthWorkoutImporter.importSamples(into: context) {
            // A second import finishes before the first query returns, without saving yet.
            innerCount = try await HealthWorkoutImporter.importSamples(into: self.context) { [workout] }
            return [workout]
        }
        try context.save()
        let repeatCount = try await HealthWorkoutImporter.importSamples(into: context) { [workout] }

        XCTAssertEqual(innerCount, 1)
        XCTAssertEqual(outerCount, 0)
        XCTAssertEqual(repeatCount, 0)
        XCTAssertEqual(try entries().count, 1)
        XCTAssertEqual(try entries().first?.calories, 180)
    }

    func testDuplicateSamplesInOneQueryAreImportedOnce() async throws {
        var workout = sample(calories: 180.6)
        workout.duration = 1836
        let other = sample(calories: nil)
        let imported = try await HealthWorkoutImporter.importSamples(into: context) { [workout, workout, other] }

        XCTAssertEqual(imported, 2)
        let all = try entries()
        XCTAssertEqual(all.count, 2)
        let entry = try XCTUnwrap(all.first { $0.sourceID == workout.id.uuidString })
        XCTAssertEqual(entry.minutes, 31)
        XCTAssertEqual(entry.calories, 181)
        XCTAssertEqual(entry.activity, workout.activity)
        XCTAssertEqual(entry.date, workout.date)
        XCTAssertEqual(all.first { $0.sourceID == other.id.uuidString }?.calories, 0)
    }

    func testManualEntriesWithoutHealthIDsArePreserved() async throws {
        let manual = ExerciseEntry(date: date, activity: "Walking", minutes: 30, calories: 200)
        context.insert(manual)
        let workout = sample()

        let imported = try await HealthWorkoutImporter.importSamples(into: context) { [workout] }

        XCTAssertEqual(imported, 1)
        XCTAssertEqual(try entries().count, 2)
        XCTAssertNil(manual.sourceID)
        XCTAssertEqual(manual.calories, 200)
    }

    func testFailedQueryDoesNotInsertAnything() async throws {
        enum QueryError: Error { case failed }
        do {
            _ = try await HealthWorkoutImporter.importSamples(into: context) { throw QueryError.failed }
            XCTFail("The query error should reach the caller")
        } catch QueryError.failed {
            XCTAssertTrue(try entries().isEmpty)
        }
    }

    func testDeletedHealthWorkoutIsNotImportedAgain() async throws {
        let suiteName = "HealthWorkoutImporterTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workout = sample()

        _ = try await HealthWorkoutImporter.importSamples(into: context, defaults: defaults) { [workout] }
        let entry = try XCTUnwrap(try entries().first)
        context.deleteExerciseEntry(entry, defaults: defaults)
        try context.save()
        let imported = try await HealthWorkoutImporter.importSamples(into: context, defaults: defaults) { [workout] }

        XCTAssertEqual(imported, 0)
        XCTAssertTrue(try entries().isEmpty)
    }
}
