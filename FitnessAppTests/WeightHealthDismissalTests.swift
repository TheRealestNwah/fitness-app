import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class WeightHealthDismissalTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() async throws {
        container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        context = container.mainContext
        suiteName = "WeightHealthDismissalTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func healthWeighIn(_ id: UUID) -> WeightEntry {
        let entry = WeightEntry(date: .now, weightKg: 80.2, note: "From Apple Health")
        entry.sourceID = id.uuidString
        context.insert(entry)
        return entry
    }

    func testDeletedHealthWeighInIsSkippedOnImport() {
        let id = UUID()
        context.deleteWeightEntries([healthWeighIn(id)], undo: UndoCenter(), defaults: defaults)

        let known = HealthDismissals.ids(.weight, defaults: defaults)
        let sample = HealthQuantitySample(id: id, date: .now, value: 80.2, fromThisApp: false)
        XCTAssertTrue(HealthImportRules.newSamples([sample], existingIDs: known).isEmpty)
    }

    func testUndoForgetsTheDismissal() throws {
        let id = UUID()
        let undo = UndoCenter()
        context.deleteWeightEntries([healthWeighIn(id)], undo: undo, defaults: defaults)
        undo.undo()

        XCTAssertTrue(HealthDismissals.ids(.weight, defaults: defaults).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WeightEntry>()).first?.sourceID, id.uuidString)
    }

    func testManualWeighInsAreNotRecorded() {
        let entry = WeightEntry(date: .now, weightKg: 80)
        context.insert(entry)
        context.deleteWeightEntries([entry], undo: UndoCenter(), defaults: defaults)
        XCTAssertTrue(HealthDismissals.ids(.weight, defaults: defaults).isEmpty)
    }
}
