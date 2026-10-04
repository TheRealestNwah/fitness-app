import SwiftUI
import SwiftData

/// Today card for weight-loss medication: when the next dose is due, where to inject, and weight
/// change since starting. Only shown when medication tracking is on in Settings.
struct MedicationCard: View {
    @Environment(UserProfile.self) private var profile
    @Query(sort: \MedicationDose.date, order: .reverse) private var doses: [MedicationDose]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @State private var logging = false

    private var medication: MedicationPlanner.Medication? { MedicationPlanner.medication(named: profile.medicationName) }
    private var intervalDays: Int { medication?.intervalDays ?? profile.medicationIntervalDays }

    var body: some View {
        if profile.medicationEnabled {
            let due = MedicationPlanner.nextDose(after: doses.first?.date, intervalDays: intervalDays)
            let overdue = MedicationPlanner.daysUntil(due) < 0
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Medication", systemImage: "syringe")
                        .font(.headline)
                    Spacer()
                    NavigationLink {
                        MedicationView()
                    } label: {
                        Text("History").font(.subheadline)
                    }
                }
                Text(profile.medicationName.isEmpty ? String(localized: "Your medication") : profile.medicationName)
                    .font(.subheadline.weight(.medium))
                Label(MedicationPlanner.countdown(due), systemImage: overdue ? "exclamationmark.circle" : "calendar")
                    .foregroundStyle(overdue ? Color.orange : Color.primary)
                if medication?.isInjection ?? true, let last = doses.first {
                    Text("Next site: \(MedicationPlanner.nextSite(after: last.site).label)")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
                if let start = profile.medicationStartDate,
                   let change = MedicationPlanner.weightChange(since: start,
                                                               weights: weights.map { (date: $0.date, kg: $0.weightKg) }) {
                    Text("\(profile.units.weightString(kg: change, decimals: 1, signed: true)) since starting")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
                Button {
                    logging = true
                } label: {
                    Label("Log dose", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .strideSheet(isPresented: $logging) { LogDoseSheet() }
        }
    }
}

/// Every dose, newest first, with import from Apple Health.
struct MedicationView: View {
    @Environment(\.modelContext) private var context
    @Environment(UserProfile.self) private var profile
    @Query(sort: \MedicationDose.date, order: .reverse) private var doses: [MedicationDose]
    @State private var logging = false
    @State private var importing = false
    @State private var importNote: String?

    var body: some View {
        List {
            if doses.isEmpty {
                ContentUnavailableView {
                    Label("No doses yet", systemImage: "syringe")
                } description: {
                    Text("Log each dose to see when the next is due and keep injection sites rotating.")
                } actions: {
                    Button("Log a dose") { logging = true }
                        .buttonStyle(.borderedProminent)
                }
            }
            ForEach(doses) { dose in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(dose.medication.isEmpty ? String(localized: "Dose") : dose.medication)
                        Spacer()
                        if dose.doseMg > 0 {
                            Text("\(dose.doseMg.cleanString) mg").monospacedDigit()
                        }
                    }
                    Text(dose.date.formatted(date: .abbreviated, time: .shortened)
                         + (dose.site.map { " · \($0.label)" } ?? ""))
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                    if !dose.sideEffects.isEmpty || !dose.note.isEmpty {
                        Text((dose.sideEffects + (dose.note.isEmpty ? [] : [dose.note])).joined(separator: ", "))
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets { context.delete(doses[index]) }
                try? context.save()
            }
            if #available(iOS 26.0, macOS 26.0, *), HealthSettings.isEnabled, HealthKitManager.isAvailable {
                Section {
                    Button {
                        importFromHealth()
                    } label: {
                        Label(importing ? "Importing…" : "Import doses from Health", systemImage: "heart.text.square")
                    }
                    .disabled(importing)
                } footer: {
                    Text(importNote ?? String(localized: "Adds GLP-1 doses you logged in the Health app's Medications section over the last year."))
                }
            }
        }
        .navigationTitle("Medication")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { logging = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Log dose")
            }
        }
        .strideSheet(isPresented: $logging) { LogDoseSheet() }
    }

    private func importFromHealth() {
        #if os(iOS) && compiler(>=6.2)
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        importing = true
        Task { @MainActor in
            defer { importing = false }
            do {
                let since = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
                let found = try await MedicationHealthImport.doses(since: since)
                let known = Set(doses.compactMap(\.healthID))
                var added = 0
                for dose in found where !known.contains(dose.id.uuidString) {
                    let entry = MedicationDose(date: dose.date, medication: dose.medication, doseMg: dose.doseMg ?? 0)
                    entry.healthID = dose.id.uuidString
                    context.insert(entry)
                    added += 1
                }
                try? context.save()
                importNote = added == 0 ? String(localized: "No new doses found in Health.")
                                        : String(localized: "Added \(added) doses from Health.")
            } catch {
                importNote = error.localizedDescription
            }
        }
        #endif
    }
}

/// Log a dose: when, how much, where, and how you've felt since the last one.
struct LogDoseSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(UserProfile.self) private var profile
    @Query(sort: \MedicationDose.date, order: .reverse) private var doses: [MedicationDose]

    @State private var date = Date.now
    @State private var name = ""
    @State private var doseMg: Double?
    @State private var site: InjectionSite?
    @State private var effects: Set<String> = []
    @State private var note = ""
    @State private var loaded = false

    private var medication: MedicationPlanner.Medication? { MedicationPlanner.medication(named: name) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("When", selection: $date, in: ...Date.now)
                    Picker("Medication", selection: $name) {
                        ForEach(MedicationPlanner.medications) { Text($0.name).tag($0.name) }
                        if !name.isEmpty, medication == nil { Text(name).tag(name) }
                    }
                    DecimalField(title: "Dose", value: $doseMg, unit: "mg")
                    if let doses = medication?.doses {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(doses, id: \.self) { mg in
                                    Button("\(mg.cleanString) mg") { doseMg = mg }
                                        .buttonStyle(.bordered)
                                        .tint(doseMg == mg ? Color.accentColor : Color.secondary)
                                        .controlSize(.small)
                                }
                            }
                        }
                    }
                }
                if medication?.isInjection ?? true {
                    Section {
                        Picker("Injection site", selection: $site) {
                            Text("Not recorded").tag(InjectionSite?.none)
                            ForEach(InjectionSite.allCases) { Text($0.label).tag(InjectionSite?.some($0)) }
                        }
                    } footer: {
                        if let last = doses.first?.site {
                            Text("Last time: \(last.label). Rotating sites helps avoid lumps and irritation.")
                        }
                    }
                }
                Section("Since your last dose") {
                    ForEach(MedicationPlanner.sideEffects, id: \.self) { effect in
                        Toggle(effect, isOn: Binding(get: { effects.contains(effect) },
                                                     set: { on in if on { effects.insert(effect) } else { effects.remove(effect) } }))
                    }
                    TextField("Note (optional)", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Log dose")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                name = doses.first?.medication ?? profile.medicationName
                if name.isEmpty { name = MedicationPlanner.medications[0].name }
                doseMg = doses.first?.doseMg ?? (profile.medicationDoseMg > 0 ? profile.medicationDoseMg : nil)
                if medication?.isInjection ?? true { site = MedicationPlanner.nextSite(after: doses.first?.site) }
            }
        }
    }

    private func save() {
        let dose = MedicationDose(date: date, medication: name, doseMg: doseMg ?? 0,
                                  site: medication?.isInjection ?? true ? site : nil,
                                  sideEffects: MedicationPlanner.sideEffects.filter(effects.contains),
                                  note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(dose)
        if profile.medicationStartDate == nil { profile.medicationStartDate = date }
        try? context.save()
        NotificationManager.sync(with: profile)
        dismiss()
    }
}

/// Settings → Profile: turn medication tracking on and set the usual medication and reminder.
struct MedicationSettingsSection: View {
    @Bindable var profile: UserProfile

    var body: some View {
        Section {
            Toggle("Track medication", isOn: $profile.medicationEnabled)
            if profile.medicationEnabled {
                Picker("Medication", selection: $profile.medicationName) {
                    Text("Not set").tag("")
                    ForEach(MedicationPlanner.medications) { Text($0.name).tag($0.name) }
                }
                if MedicationPlanner.medication(named: profile.medicationName) == nil {
                    Picker("Schedule", selection: $profile.medicationIntervalDays) {
                        Text("Weekly").tag(7)
                        Text("Daily").tag(1)
                    }
                }
                DatePicker("Started", selection: Binding(get: { profile.medicationStartDate ?? .now },
                                                         set: { profile.medicationStartDate = $0 }),
                           in: ...Date.now, displayedComponents: .date)
                Toggle("Dose reminder", isOn: $profile.medicationReminderEnabled)
                if profile.medicationReminderEnabled {
                    Picker("Time", selection: $profile.medicationReminderHour) {
                        ForEach(6..<23, id: \.self) { hour in
                            Text(Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now)?
                                .formatted(.dateTime.hour()) ?? "\(hour)").tag(hour)
                        }
                    }
                }
            }
        } header: {
            Text("Medication")
        } footer: {
            Text("For GLP-1 medication such as semaglutide or tirzepatide: log doses, see when the next is due, rotate injection sites and note side effects. Stride doesn't give medical advice; follow your prescriber.")
        }
        .onChange(of: profile.medicationEnabled) { _, _ in reminderChanged() }
        .onChange(of: profile.medicationReminderEnabled) { _, _ in reminderChanged() }
        .onChange(of: profile.medicationReminderHour) { _, _ in reminderChanged() }
        .onChange(of: profile.medicationName) { _, _ in reminderChanged() }
    }

    private func reminderChanged() {
        Task { @MainActor in
            if profile.medicationEnabled, profile.medicationReminderEnabled {
                _ = await NotificationManager.requestAuthorization()
            }
            NotificationManager.sync(with: profile)
        }
    }
}
