import Foundation
import SwiftData

/// One fast: started, and ended once the user stops it. Kept alongside the diary.
@Model
final class FastingSession {
    var uuid: UUID = UUID()
    var start: Date = Date()
    var end: Date?
    var targetHours: Double = 16

    init(start: Date = .now, targetHours: Double) {
        self.uuid = UUID()
        self.start = start
        self.targetHours = targetHours
    }

    var isActive: Bool { end == nil }
}
