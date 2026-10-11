import SwiftUI
import SwiftData

/// Today's workouts and how many calories they add back.
struct ExerciseCard: View {
    var weightKg: Double

    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter
    @Query private var today: [ExerciseEntry]
    @AppStorage(ExerciseSettings.earnBackPercentKey) private var earnBackPercent = 0
    @AppStorage(HealthSettings.enabledKey) private var healthEnabled = false
    @State private var showLog = false
    @State private var editing: ExerciseEntry?

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
            #if os(iOS) && compiler(>=6.2)
            if #available(iOS 26.0, macOS 26.0, *), healthEnabled, HealthKitManager.isAvailable {
                PhoneWorkoutPanel(weightKg: weightKg)
            }
            #endif
            if today.isEmpty {
                Text("Nothing logged today.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            } else {
                ForEach(today) { entry in
                    Button { editing = entry } label: {
                        ExerciseRow(entry: entry)
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edits this workout")
                    .contextMenu {
                        Button { editing = entry } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) {
                            context.deleteExerciseEntries([entry], undo: undoCenter)
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
        .strideSheet(isPresented: $showLog) { LogExerciseSheet(weightKg: weightKg) }
        .strideSheet(item: $editing) { LogExerciseSheet(weightKg: weightKg, entry: $0) }
    }
}

#if os(iOS) && compiler(>=6.2)
/// Start, pause and finish a workout recorded on this iPhone.
@available(iOS 26.0, macOS 26.0, *)
private struct PhoneWorkoutPanel: View {
    var weightKg: Double

    @Environment(\.modelContext) private var context
    @State private var recorder = PhoneWorkoutRecorder.shared
    @State private var confirmingEnd = false
    /// Seconds recorded when End was tapped, which decides whether the dialog offers Save.
    @State private var secondsAtEnd: TimeInterval = 0

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
            case .unsaved:
                unsaved
            }
            if let error = recorder.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let notice = recorder.notice {
                HStack(alignment: .firstTextBaseline) {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Button("OK") { recorder.notice = nil }
                        .font(.caption)
                }
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
            Button {
                secondsAtEnd = recorder.elapsed(at: .now)
                confirmingEnd = true
            } label: { Label("End", systemImage: "stop.fill") }
                .buttonStyle(.borderedProminent)
        }
        .buttonStyle(.bordered)
        .font(.subheadline)
        .confirmationDialog("End workout?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            if PhoneWorkoutRules.shouldSave(seconds: secondsAtEnd) {
                Button("Save workout") {
                    Task { await recorder.finish(weightKg: weightKg, into: context) }
                }
            }
            Button("Discard", role: .destructive) {
                Task { await recorder.discard() }
            }
        } message: {
            Text(PhoneWorkoutRules.endMessage(seconds: secondsAtEnd))
        }
    }

    /// The workout ended but didn't save: try again or let it go.
    @ViewBuilder private var unsaved: some View {
        let kind = recorder.kind ?? .walking
        Label("\(kind.name) not saved yet", systemImage: kind.systemImage)
            .font(.subheadline.weight(.semibold))
        HStack {
            Button("Discard", role: .destructive) {
                Task { await recorder.discard() }
            }
            Button {
                Task { await recorder.retrySave(weightKg: weightKg, into: context) }
            } label: { Label("Try again", systemImage: "arrow.clockwise") }
                .buttonStyle(.borderedProminent)
        }
        .buttonStyle(.bordered)
        .font(.subheadline)
    }
}
#endif

/// One logged workout: activity, a Health badge when imported, and duration and calories.
struct ExerciseRow: View {
    let entry: ExerciseEntry

    var body: some View {
        HStack {
            Text(entry.activity)
                .foregroundStyle(Color.primary)
            if entry.sourceID != nil {
                Image(systemName: "heart.fill").font(.caption2).foregroundStyle(.pink)
                    .accessibilityLabel("From Apple Health")
            }
            Spacer()
            Text("\(Int(entry.minutes.rounded())) min · \(Energy.string(entry.calories))")
                .foregroundStyle(Color.secondary)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}

/// Logs a workout by hand, or edits one already logged.
struct LogExerciseSheet: View {
    var weightKg: Double
    /// The workout to edit; nil logs a new one.
    var entry: ExerciseEntry?
    /// The day a new workout is for.
    var day: Date = .now

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var activityName = ExerciseCatalog.activities[0].name
    @State private var minutes: Int? = 30
    @State private var calories: Double?
    @State private var when = Date.now
    @State private var loaded = false

    private var activity: ExerciseCatalog.Activity? {
        ExerciseCatalog.activities.first { $0.name == activityName }
    }

    /// The catalog, plus the entry's own activity when it isn't in it (such as one from Apple Health).
    private var activityNames: [String] {
        let names = ExerciseCatalog.activities.map(\.name)
        return names.contains(activityName) ? names : [activityName] + names
    }

    private var estimate: Double? {
        activity.map { ExerciseCatalog.netCalories(met: $0.met, weightKg: weightKg, minutes: Double(minutes ?? 0)) }
    }

    private var canSave: Bool { (minutes ?? 0) > 0 && (calories != nil || estimate != nil) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Activity", selection: $activityName) {
                        ForEach(activityNames, id: \.self) { name in
                            Label(name, systemImage: ExerciseCatalog.activities.first { $0.name == name }?.systemImage
                                  ?? "figure.mixed.cardio")
                                .tag(name)
                        }
                    }
                    IntField(title: "Duration", value: $minutes, unit: "min")
                    DatePicker("When", selection: $when, in: ...Date.now)
                }
                Section {
                    DecimalField(title: "Calories", value: $calories, unit: "kcal")
                } footer: {
                    if let estimate {
                        Text("About \(Energy.string(estimate)) above resting for your weight. Enter your watch's number instead if you have one.")
                    } else {
                        Text("Enter the calories from your watch or the machine.")
                    }
                }
                if entry?.sourceID != nil {
                    Section {
                        Text("This workout came from Apple Health. Changes here only affect Stride.")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .navigationTitle(entry == nil ? "Log exercise" : "Edit exercise")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(entry == nil ? "Log" : "Save", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
        .presentationDetents([.medium, .large])
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let entry {
            activityName = entry.activity
            minutes = Int(entry.minutes.rounded())
            calories = entry.calories
            when = entry.date
        } else if !Calendar.current.isDateInToday(day) {
            // A past day from the diary: midday, so it lands on that day whatever the time zone does.
            when = day.startOfDay.addingTimeInterval(12 * 3600)
        }
    }

    private func save() {
        let duration = Double(minutes ?? 0)
        let kcal = calories ?? estimate?.rounded() ?? 0
        if let entry {
            entry.activity = activityName
            entry.minutes = duration
            entry.calories = kcal
            entry.date = when
        } else {
            context.insert(ExerciseEntry(date: when, activity: activityName, minutes: duration, calories: kcal))
        }
        try? context.save()
        dismiss()
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
