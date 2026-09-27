import Foundation
import SwiftData

@Model
final class VitalsEntry {
    var uuid: UUID = UUID()
    var date: Date = Date()
    var systolic: Int?
    var diastolic: Int?
    var restingHeartRate: Int?
    var bodyFatPercent: Double?
    var waistCm: Double?
    var hipCm: Double?
    var chestCm: Double?
    var sleepHours: Double?
    var bloodGlucose: Double?
    var note: String = ""
    /// Set on entries maintained by the Apple Health import (one per day).
    var sourceID: String?

    init(date: Date) {
        self.uuid = UUID()
        self.date = date
    }

    var isEmpty: Bool {
        systolic == nil && diastolic == nil && restingHeartRate == nil && bodyFatPercent == nil
            && waistCm == nil && hipCm == nil && chestCm == nil && sleepHours == nil && bloodGlucose == nil
    }

    /// Numeric value for a given vital, used for charting. Blood pressure returns systolic.
    func value(for kind: VitalKind) -> Double? {
        switch kind {
        case .bloodPressure: return systolic.map(Double.init)
        case .restingHeartRate: return restingHeartRate.map(Double.init)
        case .bodyFat: return bodyFatPercent
        case .waist: return waistCm
        case .hips: return hipCm
        case .chest: return chestCm
        case .sleep: return sleepHours
        case .bloodGlucose: return bloodGlucose
        }
    }
}
