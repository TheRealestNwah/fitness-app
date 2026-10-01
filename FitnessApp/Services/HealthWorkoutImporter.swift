import Foundation
import SwiftData

/// Values read from Health, kept separate from HKWorkout so import ordering can be tested.
struct HealthWorkoutSample {
    var id: UUID
    var date: Date
    var activity: String
    var duration: TimeInterval
    var activeCalories: Double?
}

enum HealthWorkoutImporter {
    /// Returns the number of new entries. The caller saves the context with the other Health imports.
    @MainActor
    static func importSamples(into context: ModelContext, defaults: UserDefaults = .standard,
                              query: @MainActor () async throws -> [HealthWorkoutSample]) async throws -> Int {
        let workouts = try await query()

        // A recording or another import may have saved while Health's query was suspended.
        // Reconcile now, without another await between this fetch and the inserts.
        var knownIDs = Set(try context.fetch(FetchDescriptor<ExerciseEntry>()).compactMap(\.sourceID))
        // Workouts whose entries were deleted stay deleted.
        knownIDs.formUnion(HealthDismissals.ids(.workout, defaults: defaults))
        var imported = 0
        for workout in workouts {
            let sourceID = workout.id.uuidString
            guard knownIDs.insert(sourceID).inserted else { continue }
            // Keep existing entries untouched, including estimates when Health has no energy sample.
            let entry = ExerciseEntry(date: workout.date, activity: workout.activity,
                                      minutes: (workout.duration / 60).rounded(),
                                      calories: (workout.activeCalories ?? 0).rounded())
            entry.sourceID = sourceID
            context.insert(entry)
            imported += 1
        }
        return imported
    }
}

extension ModelContext {
    /// Deletes an exercise entry. One imported from Health is remembered so the next import skips it.
    @MainActor
    func deleteExerciseEntry(_ entry: ExerciseEntry, defaults: UserDefaults = .standard) {
        if let sourceID = entry.sourceID {
            HealthDismissals.dismiss([sourceID], kind: .workout, defaults: defaults)
        }
        delete(entry)
    }
}
