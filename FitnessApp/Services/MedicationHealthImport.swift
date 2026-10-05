import Foundation
import HealthKit

// The HealthKit Medications API needs the iOS 26 SDK (Xcode 26, Swift 6.2).
#if os(iOS) && compiler(>=6.2)
/// Reads GLP-1 doses people logged in the Health app's Medications section.
@available(iOS 26.0, macOS 26.0, *)
enum MedicationHealthImport {
    struct Dose: Equatable {
        var id: UUID
        var date: Date
        var medication: String
        var doseMg: Double?
    }

    /// Taken doses of GLP-1 medications since `since`, newest first. Asks for access to the
    /// person's medications first; Health shows which ones to share.
    static func doses(since: Date, store: HKHealthStore = HKHealthStore()) async throws -> [Dose] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestPerObjectReadAuthorization(for: HKObjectType.userAnnotatedMedicationType(), predicate: nil) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        let medications = try await HKUserAnnotatedMedicationQueryDescriptor(predicate: nil, limit: nil).result(for: store)
        var names: [HKHealthConceptIdentifier: String] = [:]
        for annotated in medications {
            let text = annotated.medication.displayText
            guard MedicationPlanner.isGLP1(text) || MedicationPlanner.isGLP1(annotated.nickname ?? "") else { continue }
            names[annotated.medication.identifier] = annotated.nickname ?? text
        }
        guard !names.isEmpty else { return [] }

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.sample(type: HKObjectType.medicationDoseEventType(),
                                 predicate: HKQuery.predicateForSamples(withStart: since, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)])
        return try await descriptor.result(for: store).compactMap { sample in
            guard let event = sample as? HKMedicationDoseEvent, event.logStatus == .taken,
                  let name = names[event.medicationConceptIdentifier] else { return nil }
            let mg = event.unit == HKUnit.gramUnit(with: .milli) ? event.doseQuantity : nil
            return Dose(id: event.uuid, date: event.startDate, medication: name, doseMg: mg)
        }
    }
}
#endif
