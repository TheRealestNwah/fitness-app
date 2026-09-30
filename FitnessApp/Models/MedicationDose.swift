import Foundation
import SwiftData

/// A dose of weight-loss medication (a GLP-1 injection or tablet), with where it was injected
/// and any side effects noticed since the last one.
@Model
final class MedicationDose {
    var uuid: UUID = UUID()
    var date: Date = Date()
    var medication: String = ""
    var doseMg: Double = 0
    /// `InjectionSite` raw value; nil for tablets or when not recorded.
    var siteRaw: String?
    /// Chosen from `MedicationPlanner.sideEffects`.
    var sideEffects: [String] = []
    var note: String = ""
    /// The Apple Health dose event this came from, so an import never adds it twice.
    var healthID: String?

    init(date: Date, medication: String, doseMg: Double, site: InjectionSite? = nil,
         sideEffects: [String] = [], note: String = "") {
        self.uuid = UUID()
        self.date = date
        self.medication = medication
        self.doseMg = doseMg
        self.siteRaw = site?.rawValue
        self.sideEffects = sideEffects
        self.note = note
    }

    var site: InjectionSite? {
        get { siteRaw.flatMap(InjectionSite.init(rawValue:)) }
        set { siteRaw = newValue?.rawValue }
    }
}

/// Injection sites in the order they're usually rotated through.
enum InjectionSite: String, CaseIterable, Identifiable {
    case abdomenLeft, abdomenRight, thighLeft, thighRight, armLeft, armRight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .abdomenLeft: String(localized: "Abdomen, left")
        case .abdomenRight: String(localized: "Abdomen, right")
        case .thighLeft: String(localized: "Thigh, left")
        case .thighRight: String(localized: "Thigh, right")
        case .armLeft: String(localized: "Upper arm, left")
        case .armRight: String(localized: "Upper arm, right")
        }
    }
}
