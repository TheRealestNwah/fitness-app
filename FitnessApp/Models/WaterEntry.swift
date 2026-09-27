import Foundation
import SwiftData

@Model
final class WaterEntry {
    var uuid: UUID = UUID()
    var date: Date = Date()
    var amountMl: Double = 250

    init(date: Date, amountMl: Double) {
        self.uuid = UUID()
        self.date = date
        self.amountMl = amountMl
    }
}
