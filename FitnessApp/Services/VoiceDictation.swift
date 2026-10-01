import AVFoundation
import Observation
import Speech

/// Keeps permission requests and late recognition callbacks tied to the recording that started them.
struct VoiceDictationSession {
    enum Status: Equatable {
        case idle, preparing, listening
        case denied, unavailable
    }

    private(set) var status: Status = .idle
    private(set) var transcript = ""
    private(set) var id: UUID?

    mutating func prepare() -> UUID? {
        guard status != .preparing, status != .listening else { return nil }
        let id = UUID()
        self.id = id
        transcript = ""
        status = .preparing
        return id
    }

    mutating func ready(id: UUID) {
        guard self.id == id else { return }
        status = .listening
    }

    mutating func fail(id: UUID, denied: Bool = false) {
        guard self.id == id else { return }
        self.id = nil
        status = denied ? .denied : .unavailable
    }

    /// Returns true when the current recording has finished and its audio resources can be released.
    mutating func receive(id: UUID, text: String?, finished: Bool, failed: Bool) -> Bool {
        guard self.id == id else { return false }
        if let text { transcript = text }
        guard finished else { return false }
        self.id = nil
        // Errors after the user taps Stop are normal; errors while listening must be visible.
        if status == .listening { status = failed ? .unavailable : .idle }
        return true
    }

    mutating func stop() {
        if status == .preparing { id = nil }
        if status == .preparing || status == .listening { status = .idle }
    }
}

/// Speech to text for describing a meal, on device where the phone supports it. The transcript
/// goes through the same parser as typed sentences.
@Observable
@MainActor
final class VoiceDictation {
    typealias Status = VoiceDictationSession.Status

    private var session = VoiceDictationSession()
    var status: Status { session.status }
    var transcript: String { session.transcript }

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var tapInstalled = false

    var isListening: Bool { status == .listening }

    func toggle() async {
        if isListening { stop() } else { await start() }
    }

    func start() async {
        guard let id = session.prepare() else { return }
        // Cancel a previous task that may still be finishing after Stop.
        task?.cancel()
        task = nil
        let authorized = await Self.authorize()
        guard session.id == id else { return }
        guard authorized else {
            session.fail(id: id, denied: true)
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            session.fail(id: id)
            return
        }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = false
            // Simulator speech assets can be unavailable even when support is reported.
            #if !targetEnvironment(simulator)
            if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
            #endif
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                releaseAudio()
                session.fail(id: id)
                return
            }
            self.request = request
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
                request.append(buffer)
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            session.ready(id: id)
            task = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let finished = error != nil || result?.isFinal == true
                let failed = error != nil
                Task { @MainActor in
                    guard let self else { return }
                    if self.session.receive(id: id, text: text, finished: finished, failed: failed) {
                        self.releaseAudio()
                        self.task = nil
                    }
                }
            }
        } catch {
            releaseAudio()
            session.fail(id: id)
        }
    }

    /// Stops listening; the recogniser still delivers its final transcript.
    func stop() {
        session.stop()
        releaseAudio()
    }

    /// Removes the tap even if engine.start() threw before the engine began running.
    private func releaseAudio() {
        engine.stop()
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func authorize() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
