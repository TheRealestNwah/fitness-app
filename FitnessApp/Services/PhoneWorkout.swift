import Foundation
import HealthKit
import Observation
import SwiftData

/// Activities that can be recorded live on iPhone (iOS 26 and later).
enum PhoneWorkoutKind: String, CaseIterable, Identifiable {
    case walking, running, cycling, hiking

    var id: String { rawValue }

    var name: String {
        switch self {
        case .walking: String(localized: "Walk")
        case .running: String(localized: "Run")
        case .cycling: String(localized: "Cycle")
        case .hiking: String(localized: "Hike")
        }
    }

    var systemImage: String {
        switch self {
        case .walking: "figure.walk"
        case .running: "figure.run"
        case .cycling: "figure.outdoor.cycle"
        case .hiking: "figure.hiking"
        }
    }

    var activityType: HKWorkoutActivityType {
        switch self {
        case .walking: .walking
        case .running: .running
        case .cycling: .cycling
        case .hiking: .hiking
        }
    }

    /// The exercise log name, the same one the Health importer gives this workout type.
    var logName: String { HealthImportRules.workoutName(activityType.rawValue) }

    /// Used to estimate calories when the phone doesn't measure any (no heart-rate sensor).
    var met: Double {
        switch self {
        case .walking: 4.3
        case .running: 8.0
        case .cycling: 6.0
        case .hiking: 6.0
        }
    }
}

/// Pure rules for recorded workouts, kept apart from HealthKit so they can be unit-tested.
enum PhoneWorkoutRules {
    /// Shorter recordings are treated as a mis-tap and discarded.
    static let minimumSeconds: TimeInterval = 60

    static func shouldSave(seconds: TimeInterval) -> Bool {
        seconds >= minimumSeconds
    }

    static func minutes(seconds: TimeInterval) -> Double {
        max((seconds / 60).rounded(), 1)
    }

    /// Calories for the exercise log: Health's active energy when the session measured some,
    /// otherwise the same above-resting estimate the manual log uses.
    static func calories(activeKcal: Double, kind: PhoneWorkoutKind, weightKg: Double, seconds: TimeInterval) -> Double {
        if activeKcal > 0 { return activeKcal.rounded() }
        return ExerciseCatalog.netCalories(met: kind.met, weightKg: weightKg, minutes: seconds / 60).rounded()
    }

    /// "4:05" under an hour, "1:02:03" after.
    static func elapsedString(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let h = total / 3600, m = total / 60 % 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

#if compiler(>=6.2)
/// Runs one HealthKit workout session on iPhone. On finish the workout is saved to Health
/// and added to the exercise log with the Health workout's id, so the importer skips it.
@available(iOS 26.0, *)
@MainActor
@Observable
final class PhoneWorkoutRecorder: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    enum Phase: Equatable { case idle, starting, running, paused, saving }

    static let shared = PhoneWorkoutRecorder()

    private(set) var phase: Phase = .idle
    private(set) var kind: PhoneWorkoutKind?
    private(set) var activeKcal: Double = 0
    var lastError: String?

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    @ObservationIgnored private var startDate: Date?
    @ObservationIgnored private var ended: CheckedContinuation<Void, Never>?

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned),
         HKQuantityType(.distanceWalkingRunning), HKQuantityType(.distanceCycling)]
    }

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.activeEnergyBurned), HKQuantityType(.heartRate)]
    }

    var isActive: Bool { phase != .idle }

    /// Time recorded so far, leaving out pauses.
    func elapsed(at date: Date) -> TimeInterval {
        builder?.elapsedTime(at: date) ?? 0
    }

    func start(_ kind: PhoneWorkoutKind) async {
        guard phase == .idle, HKHealthStore.isHealthDataAvailable() else { return }
        phase = .starting
        lastError = nil
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = kind.activityType
            configuration.locationType = .outdoor
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            self.kind = kind
            activeKcal = 0
            let start = Date.now
            startDate = start
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            phase = .running
        } catch {
            lastError = String(localized: "Couldn't start the workout: \(error.localizedDescription)")
            session?.end()
            builder?.discardWorkout()
            reset()
        }
    }

    func pause() { session?.pause() }

    func resume() { session?.resume() }

    /// Ends the session, saves the workout to Health and logs it. Recordings under a minute are discarded.
    func finish(weightKg: Double, into context: ModelContext) async {
        guard let builder, let kind, phase == .running || phase == .paused else { return }
        phase = .saving
        let end = Date.now
        let seconds = builder.elapsedTime(at: end)
        await endSession()
        do {
            try await builder.endCollection(at: end)
            guard PhoneWorkoutRules.shouldSave(seconds: seconds) else {
                builder.discardWorkout()
                reset()
                return
            }
            let workout = try await builder.finishWorkout()
            let entry = ExerciseEntry(date: startDate ?? end, activity: kind.logName,
                                      minutes: PhoneWorkoutRules.minutes(seconds: seconds),
                                      calories: PhoneWorkoutRules.calories(activeKcal: activeKcal, kind: kind,
                                                                           weightKg: weightKg, seconds: seconds))
            entry.sourceID = workout?.uuid.uuidString
            context.insert(entry)
            try context.save()
        } catch {
            lastError = String(localized: "Couldn't save the workout: \(error.localizedDescription)")
        }
        reset()
    }

    func discard() async {
        guard let builder, phase == .running || phase == .paused else { return }
        phase = .saving
        await endSession()
        builder.discardWorkout()
        reset()
    }

    /// Waits for the session to report that it has ended before the builder is finished.
    private func endSession() async {
        guard let session, session.state != .ended else { return }
        await withCheckedContinuation { continuation in
            ended = continuation
            session.end()
        }
    }

    private func reset() {
        session = nil
        builder = nil
        kind = nil
        startDate = nil
        activeKcal = 0
        phase = .idle
    }

    private func sessionChanged(to state: HKWorkoutSessionState) {
        switch state {
        case .running: if phase == .paused { phase = .running }
        case .paused: if phase == .running { phase = .paused }
        case .ended, .stopped:
            ended?.resume()
            ended = nil
        default: break
        }
    }

    private func sessionFailed(_ message: String) {
        lastError = message
        ended?.resume()
        ended = nil
    }

    // MARK: HKWorkoutSessionDelegate

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in self.sessionChanged(to: toState) }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in self.sessionFailed(message) }
    }

    // MARK: HKLiveWorkoutBuilderDelegate

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let energy = HKQuantityType(.activeEnergyBurned)
        guard collectedTypes.contains(energy) else { return }
        let kcal = workoutBuilder.statistics(for: energy)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        Task { @MainActor in self.activeKcal = kcal }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
#endif
