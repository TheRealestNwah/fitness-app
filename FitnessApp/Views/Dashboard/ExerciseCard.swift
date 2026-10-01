import SwiftUI
import SwiftData

/// Today's workouts and how many calories they add back.
struct ExerciseCard: View {
    var weightKg: Double

    @Environment(\.modelContext) private var context
    @Query private var today: [ExerciseEntry]
    @AppStorage(ExerciseSettings.earnBackPercentKey) private var earnBackPercent = 0
    @AppStorage(HealthSettings.enabledKey) private var healthEnabled = false
    @State private var showLog = false

    init(weightKg: Double) {
        self.weightKg = weightKg
        let start = Calendar.current.startOfDay(for: .now)
        let end = start.adding(days: 1)
        _today = Query(filter: #Predicate<ExerciseEntry> { $0.date >= start && $0.date < end },
                       sort: \ExerciseEntry.date)
    }

    private var total: Double { today.reduce(0) { $0 + $1.calories } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Exercise", systemImage: "figure.run")
                    .font(.headline)
                Spacer()
                Button { showLog = true } label: {
                    Label("Log", systemImage: "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            #if compiler(>=6.2)
            if #available(iOS 26.0, *), healthEnabled, HealthKitManager.isAvailable {
                PhoneWorkoutPanel(weightKg: weightKg)
            }
            #endif
            if today.isEmpty {
                Text("Nothing logged today.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            } else {
                ForEach(today) { entry in
                    HStack {
                        Text(entry.activity)
                        if entry.sourceID != nil {
                            Image(systemName: "heart.fill").font(.caption2).foregroundStyle(.pink)
                                .accessibilityLabel("From Apple Health")
                        }
                        Spacer()
                        Text("\(Int(entry.minutes)) min · \(Energy.string(entry.calories))")
                            .foregroundStyle(Color.secondary)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    .contextMenu {
                        Button(role: .destructive) {
                            context.delete(entry)
                            try? context.save()
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                Text(earnBackPercent > 0
                     ? "+\(Energy.string(ExerciseCatalog.earnBack(exerciseKcal: total, percent: earnBackPercent))) added to today's budget (\(earnBackPercent)% of \(Energy.string(total)))."
                     : "Earn-back is off, so exercise doesn't change your budget. Turn it on in Settings.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .sheet(isPresented: $showLog) { LogExerciseSheet(weightKg: weightKg) }
    }
}

#if compiler(>=6.2)
/// Start, pause and finish a workout recorded on this iPhone.
@available(iOS 26.0, *)
private struct PhoneWorkoutPanel: View {
    var weightKg: Double

    @Environment(\.modelContext) private var context
    @State private var recorder = PhoneWorkoutRecorder.shared
    @State private var confirmingEnd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch recorder.phase {
            case .idle:
                Menu {
                    ForEach(PhoneWorkoutKind.allCases) { kind in
                        Button {
                            Task { await recorder.start(kind) }
                        } label: {
                            Label(kind.name, systemImage: kind.systemImage)
                        }
                    }
                } label: {
                    Label("Start workout", systemImage: "play.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            case .starting, .saving:
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .running, .paused:
                recording
            }
            if let error = recorder.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder private var recording: some View {
        let kind = recorder.kind ?? .walking
        HStack {
            Label(kind.name, systemImage: kind.systemImage)
                .font(.subheadline.weight(.semibold))
            if recorder.phase == .paused {
                Text("Paused")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(PhoneWorkoutRules.elapsedString(recorder.elapsed(at: timeline.date)))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        if recorder.activeKcal > 0 {
            Text("\(Energy.string(recorder.activeKcal)) active energy")
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .monospacedDigit()
        }
        HStack {
            if recorder.phase == .paused {
                Button { recorder.resume() } label: { Label("Resume", systemImage: "play.fill") }
            } else {
                Button { recorder.pause() } label: { Label("Pause", systemImage: "pause.fill") }
            }
            Button { confirmingEnd = true } label: { Label("End", systemImage: "stop.fill") }
                .buttonStyle(.borderedProminent)
        }
        .buttonStyle(.bordered)
        .font(.subheadline)
        .confirmationDialog("End workout?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("Save workout") {
                Task { await recorder.finish(weightKg: weightKg, into: context) }
            }
            Button("Discard", role: .destructive) {
                Task { await recorder.discard() }
            }
        } message: {
            Text("Saved workouts go to Apple Health and today's exercise. Workouts under a minute aren't saved.")
        }
    }
}
#endif

struct LogExerciseSheet: View {
    var weightKg: Double

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var activity = ExerciseCatalog.activities[0]
    @State private var minutes: Double = 30
    @State private var calories: Double?
    @State private var when = Date.now

    private var estimate: Double {
        ExerciseCatalog.netCalories(met: activity.met, weightKg: weightKg, minutes: minutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Activity", selection: $activity) {
                        ForEach(ExerciseCatalog.activities) { item in
                            Label(item.name, systemImage: item.systemImage).tag(item)
                        }
                    }
                    Stepper(value: $minutes, in: 5...300, step: 5) {
                        LabeledContent("Duration", value: "\(Int(minutes)) min")
                    }
                    DatePicker("When", selection: $when, in: ...Date.now)
                }
                Section {
                    DecimalField(title: "Calories", value: $calories, unit: "kcal")
                } footer: {
                    Text("About \(Energy.string(estimate)) above resting for your weight. Enter your watch's number instead if you have one.")
                }
            }
            .navigationTitle("Log exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        context.insert(ExerciseEntry(date: when, activity: activity.name, minutes: minutes,
                                                     calories: calories ?? estimate.rounded()))
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Settings for exercise earn-back.
struct ExerciseSection: View {
    @AppStorage(ExerciseSettings.earnBackPercentKey) private var earnBackPercent = 0

    var body: some View {
        Section {
            Picker("Earn back exercise calories", selection: $earnBackPercent) {
                Text("Off").tag(0)
                Text("Half").tag(50)
                Text("All").tag(100)
            }
        } header: {
            Text("Exercise")
        } footer: {
            Text("Adds part of today's logged exercise to your calorie budget. Half is a safer choice, since exercise estimates run high. If Apple Health active energy is also counted, the larger of the two is used so workouts aren't counted twice.")
        }
    }
}
