import Foundation
import SwiftData

@Model
final class WeightEntry {
    var uuid: UUID = UUID()
    var date: Date = Date()
    var weightKg: Double = 0
    var note: String = ""

    init(date: Date, weightKg: Double, note: String = "") {
        self.uuid = UUID()
        self.date = date
        self.weightKg = weightKg
        self.note = note
    }
}
