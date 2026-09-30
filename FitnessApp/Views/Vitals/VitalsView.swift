import SwiftUI
import SwiftData
import Charts

struct VitalsView: View {
    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Query(sort: \VitalsEntry.date, order: .reverse) private var entries: [VitalsEntry]

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showAdd = false
    @State private var editing: VitalsEntry?
    /// The vital shown beside the list on iPad; the first one with a reading until one is picked.
    @State private var selectedKind: VitalKind?

    private var units: Units { profile.units }

    private func latest(_ kind: VitalKind) -> VitalsEntry? {
        entries.first { $0.value(for: kind) != nil }
    }

    private func hasAny(_ kind: VitalKind) -> Bool { latest(kind) != nil }

    private var shownKind: VitalKind? {
        if let selectedKind, hasAny(selectedKind) { return selectedKind }
        return VitalKind.allCases.first(where: hasAny)
    }

    var body: some View {
        NavigationStack {
            Group {
                if sizeClass == .regular {
                    // iPad: the vitals on the left, the chosen vital's chart and readings on the right.
                    HStack(spacing: 0) {
                        list
                            .frame(width: 400)
                        Divider()
                        if let kind = shownKind {
                            VitalDetailView(kind: kind, embedded: true)
                                .id(kind)
                        } else {
                            Color(.systemGroupedBackground)
                        }
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Vitals")
            .navigationDestination(for: VitalKind.self) { kind in
                VitalDetailView(kind: kind)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add reading")
                }
            }
            .sheet(isPresented: $showAdd) { AddVitalsSheet() }
            .sheet(item: $editing) { AddVitalsSheet(entry: $0) }
        }
    }

    @ViewBuilder
    private func vitalRow(_ kind: VitalKind, entry: VitalsEntry) -> some View {
        if sizeClass == .regular {
            Button { selectedKind = kind } label: {
                VitalRow(kind: kind, entry: entry, units: units)
                    .foregroundStyle(Color.primary)
                    .contentShape(Rectangle())
            }
            .listRowBackground(kind == shownKind ? Color.accentColor.opacity(0.15)
                                                 : Color(.secondarySystemGroupedBackground))
            .accessibilityAddTraits(kind == shownKind ? .isSelected : [])
            .accessibilityIdentifier("vitalRow")
        } else {
            NavigationLink(value: kind) {
                VitalRow(kind: kind, entry: entry, units: units)
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(VitalKind.allCases) { kind in
                    if let entry = latest(kind) {
                        vitalRow(kind, entry: entry)
                    }
                }
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("No vitals yet", systemImage: "heart.text.square")
                    } description: {
                        Text("Blood pressure, resting heart rate, body measurements and sleep all respond to weight loss. Log them weekly to see the change.")
                    } actions: {
                        Button("Log vitals") { showAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            } header: {
                Text("Latest")
            } footer: {
                if !entries.isEmpty {
                    Text("Tap a vital to see its history. Readings are for your own tracking and are not medical advice.")
                }
            }

            if !entries.isEmpty {
                Section("Trends") {
                    if hasAny(.waist) || hasAny(.hips) || hasAny(.chest) || hasAny(.bodyFat) {
                        NavigationLink {
                            BodyTrendsView()
                        } label: {
                            Label("Measurements and body fat", systemImage: "chart.xyaxis.line")
                        }
                    }
                    NavigationLink {
                        CorrelationsView()
                    } label: {
                        Label("Sleep, sodium and patterns", systemImage: "chart.dots.scatter")
                    }
                }
            }

            if !entries.isEmpty {
                Section("All entries") {
                    ForEach(entries) { entry in
                        Button { editing = entry } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(Color.primary)
                                Text(summary(for: entry))
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { context.delete(entries[i]) }
                        try? context.save()
                    }
                }
            }
        }
    }

    private func summary(for entry: VitalsEntry) -> String {
        var parts: [String] = []
        if let s = entry.systolic, let d = entry.diastolic { parts.append("BP \(s)/\(d)") }
        if let hr = entry.restingHeartRate { parts.append("HR \(hr)") }
        if let bf = entry.bodyFatPercent { parts.append(String(format: "Body fat %.1f%%", bf)) }
        if let w = entry.waistCm { parts.append("Waist \(units.lengthString(cm: w))") }
        if let h = entry.hipCm { parts.append("Hips \(units.lengthString(cm: h))") }
        if let c = entry.chestCm { parts.append("Chest \(units.lengthString(cm: c))") }
        if let s = entry.sleepHours { parts.append(String(format: "Sleep %.1f h", s)) }
        if let g = entry.bloodGlucose { parts.append(String(format: "Glucose %.0f", g)) }
        return parts.isEmpty ? "No readings" : parts.joined(separator: " · ")
    }
}

struct VitalRow: View {
    let kind: VitalKind
    let entry: VitalsEntry
    let units: Units

    var body: some View {
        HStack {
            Image(systemName: kind.systemImage)
                .foregroundStyle(kind.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.label)
                Text(entry.date.relativeDayLabel)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(kind.display(entry: entry, units: units))
                    .font(.body.monospacedDigit().weight(.medium))
                if let note = kind.assessment(entry: entry) {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }
}

extension VitalKind {
    var tint: Color {
        switch self {
        case .bloodPressure: return .red
        case .restingHeartRate: return .pink
        case .bodyFat: return .orange
        case .waist, .hips, .chest: return .teal
        case .sleep: return .indigo
        case .bloodGlucose: return .purple
        }
    }

    var usesLength: Bool {
        switch self {
        case .waist, .hips, .chest: return true
        default: return false
        }
    }

    func unitLabel(_ units: Units) -> String {
        switch self {
        case .bloodPressure: return "mmHg"
        case .restingHeartRate: return "bpm"
        case .bodyFat: return "%"
        case .waist, .hips, .chest: return units.lengthUnit
        case .sleep: return "h"
        case .bloodGlucose: return "mg/dL"
        }
    }

    /// Value converted to display units for charting.
    func displayValue(_ entry: VitalsEntry, units: Units) -> Double? {
        guard let raw = entry.value(for: self) else { return nil }
        return usesLength ? units.lengthValue(cm: raw) : raw
    }

    func display(entry: VitalsEntry, units: Units) -> String {
        switch self {
        case .bloodPressure:
            if let s = entry.systolic, let d = entry.diastolic { return "\(s)/\(d)" }
            return "—"
        case .restingHeartRate:
            return entry.restingHeartRate.map { "\($0) bpm" } ?? "—"
        case .bodyFat:
            return entry.bodyFatPercent.map { String(format: "%.1f%%", $0) } ?? "—"
        case .waist:
            return entry.waistCm.map { units.lengthString(cm: $0) } ?? "—"
        case .hips:
            return entry.hipCm.map { units.lengthString(cm: $0) } ?? "—"
        case .chest:
            return entry.chestCm.map { units.lengthString(cm: $0) } ?? "—"
        case .sleep:
            return entry.sleepHours.map { String(format: "%.1f h", $0) } ?? "—"
        case .bloodGlucose:
            return entry.bloodGlucose.map { String(format: "%.0f mg/dL", $0) } ?? "—"
        }
    }

    func assessment(entry: VitalsEntry) -> String? {
        switch self {
        case .bloodPressure:
            guard let s = entry.systolic, let d = entry.diastolic else { return nil }
            return NutritionCalculator.bloodPressureCategory(systolic: s, diastolic: d).label
        case .restingHeartRate:
            guard let hr = entry.restingHeartRate else { return nil }
            switch hr {
            case ..<60: return "Athletic"
            case 60..<80: return "Good"
            case 80..<100: return "Above average"
            default: return "High"
            }
        case .sleep:
            guard let h = entry.sleepHours else { return nil }
            return h >= 7 ? "Well rested" : "Under 7 h"
        case .bloodGlucose:
            guard let g = entry.bloodGlucose else { return nil }
            switch g {
            case ..<70: return "Low"
            case 70..<100: return "Normal fasting"
            case 100..<126: return "Elevated"
            default: return "High"
            }
        default:
            return nil
        }
    }
}

struct VitalDetailView: View {
    let kind: VitalKind
    /// Shown beside the vitals list on iPad, where the list's title stays.
    var embedded = false

    @Environment(UserProfile.self) private var profile
    @Query(sort: \VitalsEntry.date) private var entries: [VitalsEntry]

    private var units: Units { profile.units }

    private struct Point: Identifiable {
        let id: UUID
        let date: Date
        let value: Double
        let secondary: Double?
    }

    private var points: [Point] {
        entries.compactMap { e in
            guard let v = kind.displayValue(e, units: units) else { return nil }
            let secondary = kind == .bloodPressure ? e.diastolic.map(Double.init) : nil
            return Point(id: e.uuid, date: e.date, value: v, secondary: secondary)
        }
    }

    private var change: Double? {
        guard let first = points.first?.value, let last = points.last?.value, points.count >= 2 else { return nil }
        return last - first
    }

    var body: some View {
        if embedded {
            content
        } else {
            content
                .navigationTitle(kind.label)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                if embedded {
                    Label(kind.label, systemImage: kind.systemImage)
                        .font(.title2.bold())
                        .foregroundStyle(kind.tint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let latestEntry = entries.last(where: { $0.value(for: kind) != nil }) {
                    AdaptiveStack(spacing: 12) {
                        StatTile(title: "Latest", value: kind.display(entry: latestEntry, units: units), subtitle: latestEntry.date.relativeDayLabel, systemImage: kind.systemImage, tint: kind.tint)
                        if let change {
                            StatTile(title: "Since first", value: String(format: "%+.1f %@", change, kind.unitLabel(units)), subtitle: "\(points.count) readings", systemImage: change <= 0 ? "arrow.down.right" : "arrow.up.right", tint: .secondary)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("History").font(.headline)
                    if points.count < 2 {
                        ContentUnavailableView("Not enough data", systemImage: "chart.xyaxis.line",
                                               description: Text("Log at least two readings to see a trend."))
                            .frame(height: 200)
                    } else {
                        Chart {
                            ForEach(points) { p in
                                LineMark(x: .value("Date", p.date), y: .value(kind.label, p.value), series: .value("Series", "primary"))
                                    .foregroundStyle(kind.tint)
                                    .interpolationMethod(.monotone)
                                PointMark(x: .value("Date", p.date), y: .value(kind.label, p.value))
                                    .foregroundStyle(kind.tint)
                                if let s = p.secondary {
                                    LineMark(x: .value("Date", p.date), y: .value("Diastolic", s), series: .value("Series", "secondary"))
                                        .foregroundStyle(kind.tint.opacity(0.5))
                                        .interpolationMethod(.monotone)
                                    PointMark(x: .value("Date", p.date), y: .value("Diastolic", s))
                                        .foregroundStyle(kind.tint.opacity(0.5))
                                }
                            }
                        }
                        .chartYAxisLabel(kind.unitLabel(units))
                        .frame(height: 220)
                        .accessibilityLabel("\(kind.label) history")
                        .accessibilityValue(ChartSummary.describe(points.map { (date: $0.date, value: $0.value) },
                                                                  format: { "\($0.cleanString) \(kind.unitLabel(units))" }))
                        if kind == .bloodPressure {
                            HStack(spacing: 16) {
                                Label("Systolic", systemImage: "circle.fill").foregroundStyle(kind.tint)
                                Label("Diastolic", systemImage: "circle.fill").foregroundStyle(kind.tint.opacity(0.5))
                            }
                            .font(.caption)
                        }
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Readings").font(.headline)
                    ForEach(points.reversed()) { p in
                        HStack {
                            Text(p.date.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            if let s = p.secondary {
                                Text("\(Int(p.value))/\(Int(s)) \(kind.unitLabel(units))")
                            } else {
                                Text(String(format: "%.1f %@", p.value, kind.unitLabel(units)))
                            }
                        }
                        .font(.subheadline.monospacedDigit())
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct AddVitalsSheet: View {
    var entry: VitalsEntry?

    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var systolic: Int?
    @State private var diastolic: Int?
    @State private var heartRate: Int?
    @State private var bodyFat: Double?
    @State private var waist: Double?
    @State private var hips: Double?
    @State private var chest: Double?
    @State private var sleep: Double?
    @State private var glucose: Double?
    @State private var note = ""
    @State private var loaded = false

    private var units: Units { profile.units }

    private var hasValue: Bool {
        systolic != nil || diastolic != nil || heartRate != nil || bodyFat != nil || waist != nil
            || hips != nil || chest != nil || sleep != nil || glucose != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, in: ...Date.now)
                } footer: {
                    Text("Fill in whatever you measured. Everything is optional.")
                }
                Section("Heart") {
                    IntField(title: "Systolic", value: $systolic, unit: "mmHg")
                    IntField(title: "Diastolic", value: $diastolic, unit: "mmHg")
                    if let s = systolic, let d = diastolic {
                        LabeledContent("Category", value: NutritionCalculator.bloodPressureCategory(systolic: s, diastolic: d).label)
                            .foregroundStyle(Color.secondary)
                    }
                    IntField(title: "Resting heart rate", value: $heartRate, unit: "bpm")
                }
                Section("Body") {
                    DecimalField(title: "Body fat", value: $bodyFat, unit: "%")
                    DecimalField(title: "Waist", value: $waist, unit: units.lengthUnit)
                    DecimalField(title: "Hips", value: $hips, unit: units.lengthUnit)
                    DecimalField(title: "Chest", value: $chest, unit: units.lengthUnit)
                }
                Section("Other") {
                    DecimalField(title: "Sleep last night", value: $sleep, unit: "h")
                    DecimalField(title: "Fasting glucose", value: $glucose, unit: "mg/dL")
                    TextField("Note (optional)", text: $note)
                }
                if entry != nil {
                    Section {
                        Button("Delete entry", role: .destructive) {
                            if let entry { context.delete(entry) }
                            try? context.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(entry == nil ? "Log vitals" : "Edit vitals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!hasValue)
                }
            }
            .onAppear {
                guard !loaded, let entry else { return }
                loaded = true
                date = entry.date
                systolic = entry.systolic
                diastolic = entry.diastolic
                heartRate = entry.restingHeartRate
                bodyFat = entry.bodyFatPercent
                waist = entry.waistCm.map { units.lengthValue(cm: $0) }
                hips = entry.hipCm.map { units.lengthValue(cm: $0) }
                chest = entry.chestCm.map { units.lengthValue(cm: $0) }
                sleep = entry.sleepHours
                glucose = entry.bloodGlucose
                note = entry.note
            }
        }
    }

    private func save() {
        let target = entry ?? VitalsEntry(date: date)
        target.date = date
        target.systolic = systolic
        target.diastolic = diastolic
        target.restingHeartRate = heartRate
        target.bodyFatPercent = bodyFat
        target.waistCm = waist.map { units.cm(fromDisplayLength: $0) }
        target.hipCm = hips.map { units.cm(fromDisplayLength: $0) }
        target.chestCm = chest.map { units.cm(fromDisplayLength: $0) }
        target.sleepHours = sleep
        target.bloodGlucose = glucose
        target.note = note
        if entry == nil { context.insert(target) }
        try? context.save()
        dismiss()
    }
}
