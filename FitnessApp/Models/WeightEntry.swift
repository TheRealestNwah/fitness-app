import Foundation
import SwiftData

@Model
final class WeightEntry {
    var uuid: UUID = UUID()
    var date: Date = Date()
    var weightKg: Double = 0
    var note: String = ""
    /// HealthKit sample id when the entry came from, or was written to, Apple Health.
    var sourceID: String?
    /// Optional progress photo, stored outside the database file.
    @Attribute(.externalStorage) var photo: Data?

    init(date: Date, weightKg: Double, note: String = "") {
        self.uuid = UUID()
        self.date = date
        self.weightKg = weightKg
        self.note = note
    }
}

extension WeightEntry {
    /// The note on the weigh-in onboarding creates from the starting weight.
    static let startingWeightNote = "Starting weight"

    /// Created by onboarding rather than logged by the person, so it doesn't start a streak.
    var isStartingWeight: Bool { note == Self.startingWeightNote }
}
