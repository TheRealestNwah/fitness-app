import SwiftUI
import SwiftData

/// Start or end a fast from Today, with a live ring while one is running.
struct FastingCard: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<FastingSession> { $0.end == nil }, sort: \FastingSession.start, order: .reverse)
    private var active: [FastingSession]

    @State private var customHours: Double = 16
    @State private var showCustom = false
    @State private var confirmEnd = false

    private func fast(_ session: FastingSession) -> FastingCalculator.Fast {
        .init(start: session.start, end: session.end, targetHours: session.targetHours)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Fasting", systemImage: "timer")
                .font(.headline)
            if let session = active.first {
                running(session)
            } else {
                start
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func running(_ session: FastingSession) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let fast = fast(session)
            let progress = FastingCalculator.progress(fast, now: timeline.date)
            let elapsed = FastingCalculator.elapsedHours(fast, now: timeline.date)
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: min(progress, 1), lineWidth: 10, color: progress >= 1 ? .green : .indigo)
                    VStack(spacing: 0) {
                        Text("\(Int(elapsed))h \(Int((elapsed * 60).truncatingRemainder(dividingBy: 60)))m")
                            .font(.headline.monospacedDigit())
                        Text("of \(session.targetHours.cleanString)h")
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .frame(width: 96, height: 96)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Fast progress")
                .accessibilityValue("\(Int(elapsed)) hours \(Int((elapsed * 60).truncatingRemainder(dividingBy: 60))) minutes of \(session.targetHours.cleanString) hours")
                VStack(alignment: .leading, spacing: 6) {
                    Text(progress >= 1 ? "Target reached" : "Ends \(FastingCalculator.targetEnd(fast).formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline.weight(.semibold))
                    Text("Started \(session.start.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Button(progress >= 1 ? "End fast" : "End early") {
                        if progress >= 1 { end(session) } else { confirmEnd = true }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(progress >= 1 ? .green : .orange)
                    .font(.subheadline)
                }
            }
        }
        .confirmationDialog("End this fast before its target?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End fast", role: .destructive) { end(session) }
        } message: {
            Text("It will be saved, but won't count as completed in your weekly review.")
        }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start a fast now. You'll see the countdown here.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
            HStack {
                ForEach(FastingCalculator.presets) { preset in
                    Button(preset.name) { begin(hours: preset.hours) }
                        .buttonStyle(.bordered)
                }
                Button("Custom") { showCustom.toggle() }
                    .buttonStyle(.bordered)
            }
            .font(.subheadline)
            if showCustom {
                Stepper(value: $customHours, in: FastingCalculator.customRange, step: 1) {
                    Text("\(customHours.cleanString) hours").monospacedDigit()
                }
                Button("Start \(customHours.cleanString)-hour fast") { begin(hours: customHours) }
                    .buttonStyle(.borderedProminent)
                    .font(.subheadline)
            }
        }
    }

    private func begin(hours: Double) {
        context.insert(FastingSession(targetHours: hours))
        try? context.save()
        showCustom = false
    }

    private func end(_ session: FastingSession) {
        session.end = .now
        try? context.save()
    }
}
