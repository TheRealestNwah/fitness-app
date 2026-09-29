import SwiftUI
import SwiftData

struct SettingsView: View {
    /// Presented as a sheet on iPhone (with Done); shown in the sidebar's detail column on iPad.
    var isSheet = true

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.resetAllData) private var resetAllData
    @State private var path: [SettingsPage] = []
    @State private var query = ""

    private var results: [SettingsSearch.Entry] { SettingsSearch.search(query) }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if query.isEmpty {
                    ForEach(SettingsPage.allCases) { page in
                        NavigationLink(value: page) {
                            Label(page.title, systemImage: page.systemImage)
                        }
                    }
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(results) { entry in
                        NavigationLink(value: entry.page) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                Text(entry.page.title)
                                    .font(.footnote)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search settings")
            .readableWidth()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SettingsPage.self) { page in
                SettingsPageView(page: page) {
                    if isSheet { dismiss() }
                    resetAllData()
                }
            }
            .toolbar {
                if isSheet {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
            .onDisappear { try? context.save() }
        }
    }
}

struct MacroSlider: View {
    var name: String
    @Binding var value: Double
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                Spacer()
                Text("\(Int(value))%").monospacedDigit().foregroundStyle(Color.secondary)
            }
            Slider(value: $value, in: NutritionCalculator.macroPercentRange, step: NutritionCalculator.macroPercentStep)
                .tint(color)
        }
    }
}

struct ExportSheet: View {
    let urls: [URL]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(urls, id: \.self) { url in
                        ShareLink(item: url) {
                            Label(Self.title(for: url), systemImage: Self.icon(for: url))
                        }
                    }
                } footer: {
                    Text("The summary image is for sharing your week. The health report is a one-page PDF of the last 90 days of weight and vitals to show a doctor. The CSV files open in any spreadsheet app.")
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }

    private static func title(for url: URL) -> String {
        switch url.pathExtension {
        case "png": return "Weekly summary image"
        case "pdf": return "Health report for your doctor (PDF)"
        default: return url.lastPathComponent
        }
    }

    private static func icon(for url: URL) -> String {
        switch url.pathExtension {
        case "png": return "photo"
        case "pdf": return "doc.richtext"
        default: return "tablecells"
        }
    }
}

struct ProfileEditorView: View {
    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var sex: BiologicalSex = .female
    @State private var birthDate = Date.now
    @State private var height: Double = 0
    @State private var heightFeet = 5
    @State private var heightInches = 7
    @State private var startWeight: Double = 0
    @State private var goalWeight: Double = 0
    @State private var activity: ActivityLevel = .light
    @State private var weeklyLoss: Double = 0.5
    @State private var loaded = false

    private var units: Units { profile.units }

    var body: some View {
        Form {
            Section("About you") {
                TextField("Name", text: $name)
                Picker("Sex", selection: $sex) {
                    ForEach(BiologicalSex.allCases) { Text($0.label).tag($0) }
                }
                DatePicker("Date of birth", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                if profile.unitSystem == .metric {
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("Height", value: $height, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        Text("cm").foregroundStyle(Color.secondary)
                    }
                } else {
                    Picker("Height (ft)", selection: $heightFeet) {
                        ForEach(3..<8, id: \.self) { Text("\($0) ft").tag($0) }
                    }
                    Picker("Height (in)", selection: $heightInches) {
                        ForEach(0..<12, id: \.self) { Text("\($0) in").tag($0) }
                    }
                }
                Picker("Activity", selection: $activity) {
                    ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
                }
            }
            Section("Goals") {
                HStack {
                    Text("Starting weight")
                    Spacer()
                    TextField("Start", value: $startWeight, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text(units.weightUnit).foregroundStyle(Color.secondary)
                }
                HStack {
                    Text("Goal weight")
                    Spacer()
                    TextField("Goal", value: $goalWeight, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text(units.weightUnit).foregroundStyle(Color.secondary)
                }
                Picker("Weekly loss", selection: $weeklyLoss) {
                    ForEach(WeeklyGoalRate.allCases) { r in
                        Text("\(r.label) · \(units.weightString(kg: r.rawValue, decimals: 2))").tag(r.rawValue)
                    }
                }
            }
        }
        .readableWidth()
        .navigationTitle("Body & goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            name = profile.name
            sex = profile.sex
            birthDate = profile.birthDate
            height = profile.heightCm.rounded()
            let inches = profile.heightCm * Units.inchPerCm
            heightFeet = Int(inches / 12)
            heightInches = Int((inches - Double(heightFeet) * 12).rounded())
            startWeight = (units.weightValue(kg: profile.startWeightKg) * 10).rounded() / 10
            goalWeight = (units.weightValue(kg: profile.goalWeightKg) * 10).rounded() / 10
            activity = profile.activityLevel
            weeklyLoss = profile.weeklyLossKg
        }
    }

    private func save() {
        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.sex = sex
        profile.birthDate = birthDate
        profile.heightCm = profile.unitSystem == .metric ? height : Units.cm(feet: heightFeet, inches: heightInches)
        profile.startWeightKg = units.kg(fromDisplayWeight: startWeight)
        profile.goalWeightKg = units.kg(fromDisplayWeight: goalWeight)
        profile.activityLevel = activity
        profile.weeklyLossKg = weeklyLoss
        try? context.save()
        dismiss()
    }
}
