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

    /// The kind a recovered session was started as.
    init?(activityType: HKWorkoutActivityType) {
        guard let kind = Self.allCases.first(where: { $0.activityType == activityType }) else { return nil }
        self = kind
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

    /// What the End dialog says: short recordings can only be discarded.
    static func endMessage(seconds: TimeInterval) -> String {
        shouldSave(seconds: seconds)
            ? String(localized: "Saved workouts go to Apple Health and today's exercise.")
            : String(localized: "Workouts under a minute aren't saved, so this one can only be discarded.")
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

#if os(iOS) && compiler(>=6.2)
/// Runs one HealthKit workout session on iPhone. On finish the workout is saved to Health
/// and added to the exercise log with the Health workout's id, so the importer skips it.
@available(iOS 26.0, macOS 26.0, *)
@MainActor
@Observable
final class PhoneWorkoutRecorder: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    /// `unsaved`: the workout has ended but saving it failed, so it can be retried or discarded.
    enum Phase: Equatable { case idle, starting, running, paused, saving, unsaved }

    static let shared = PhoneWorkoutRecorder()

    private(set) var phase: Phase = .idle
    private(set) var kind: PhoneWorkoutKind?
    private(set) var activeKcal: Double = 0
    var lastError: String?
    /// Something worth saying that isn't an error, such as a recording being picked up after a relaunch.
    var notice: String?

    /// How far saving an ended workout got, so a retry doesn't repeat finished steps.
    private struct Ending {
        var end: Date
        var seconds: TimeInterval
        var collected = false
        var finished = false
        var workoutID: String?
        var entry: ExerciseEntry?
    }

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    @ObservationIgnored private var startDate: Date?
    @ObservationIgnored private var ending: Ending?
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

    /// Picks up a workout that was still recording when the app quit or crashed. Call once at launch.
    func recover() async {
        guard phase == .idle, HKHealthStore.isHealthDataAvailable(),
              let session = try? await store.recoverActiveWorkoutSession() else { return }
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: session.workoutConfiguration)
        session.delegate = self
        builder.delegate = self
        self.session = session
        self.builder = builder
        let kind = PhoneWorkoutKind(activityType: session.workoutConfiguration.activityType) ?? .walking
        self.kind = kind
        startDate = session.startDate ?? builder.startDate
        activeKcal = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        phase = session.state == .paused ? .paused : .running
        notice = String(localized: "Your \(kind.name.lowercased()) was still recording when Stride closed, so it's been picked up again.")
    }

    /// Ends the session, saves the workout to Health and logs it. Recordings under a minute are discarded.
    func finish(weightKg: Double, into context: ModelContext) async {
        guard let builder, phase == .running || phase == .paused else { return }
        phase = .saving
        lastError = nil
        let end = Date.now
        ending = Ending(end: end, seconds: builder.elapsedTime(at: end))
        await endSession()
        await save(weightKg: weightKg, into: context)
    }

    /// Tries again to save a workout whose save failed.
    func retrySave(weightKg: Double, into context: ModelContext) async {
        guard phase == .unsaved else { return }
        phase = .saving
        lastError = nil
        await save(weightKg: weightKg, into: context)
    }

    /// Runs the save steps that haven't succeeded yet. On failure the workout is kept for a retry.
    private func save(weightKg: Double, into context: ModelContext) async {
        guard let builder, let kind, var progress = ending else { return reset() }
        do {
            if !progress.collected {
                try await builder.endCollection(at: progress.end)
                progress.collected = true
            }
            guard PhoneWorkoutRules.shouldSave(seconds: progress.seconds) else {
                builder.discardWorkout()
                notice = String(localized: "Workouts under a minute aren't saved.")
                return reset()
            }
            if !progress.finished {
                progress.workoutID = try await builder.finishWorkout()?.uuid.uuidString
                progress.finished = true
            }
            if progress.entry == nil {
                let entry = ExerciseEntry(date: startDate ?? progress.end, activity: kind.logName,
                                          minutes: PhoneWorkoutRules.minutes(seconds: progress.seconds),
                                          calories: PhoneWorkoutRules.calories(activeKcal: activeKcal, kind: kind,
                                                                               weightKg: weightKg, seconds: progress.seconds))
                entry.sourceID = progress.workoutID
                context.insert(entry)
                progress.entry = entry
            }
            try context.save()
            reset()
        } catch {
            ending = progress
            lastError = String(localized: "Couldn't save the workout: \(error.localizedDescription)")
            phase = .unsaved
        }
    }

    func discard() async {
        guard let builder, phase == .running || phase == .paused || phase == .unsaved else { return }
        let wasUnsaved = phase == .unsaved
        phase = .saving
        if wasUnsaved {
            // Whatever already reached Health stays there; only the unsaved log entry is dropped.
            if let entry = ending?.entry { entry.modelContext?.delete(entry) }
            if ending?.finished != true { builder.discardWorkout() }
        } else {
            await endSession()
            builder.discardWorkout()
        }
        lastError = nil
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
        ending = nil
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

/// Picks up a workout left recording by a crash or a quit. A no-op where workouts can't be recorded.
enum PhoneWorkoutRecovery {
    @MainActor static func run() async {
        #if os(iOS) && compiler(>=6.2)
        if #available(iOS 26.0, *) {
            await PhoneWorkoutRecorder.shared.recover()
        }
        #endif
    }
}
