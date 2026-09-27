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

    init(date: Date, weightKg: Double, note: String = "") {
        self.uuid = UUID()
        self.date = date
        self.weightKg = weightKg
        self.note = note
    }
}
