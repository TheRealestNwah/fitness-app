import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var foodLogs: [FoodLogEntry]
    @Query private var vitals: [VitalsEntry]

    @AppStorage(Appearance.storageKey) private var appearanceRaw = Appearance.system.rawValue
    @AppStorage(HealthSettings.enabledKey) private var healthEnabled = false
    @AppStorage(HealthSettings.creditPercentKey) private var healthCreditPercent = 0
    @State private var healthStatus: String?
    @State private var healthBusy = false
    @State private var showResetConfirm = false
    @State private var exportURLs: [URL] = []
    @State private var showExport = false
    @State private var notificationsDenied = false

    private var units: Units { profile.units }
    private var currentKg: Double { weights.first?.weightKg ?? profile.startWeightKg }

    private var maintenanceEstimate: MaintenanceEstimate? {
        AdaptiveTargetCalculator.estimate(
            foodLogs: foodLogs.map { WeeklyReviewCalculator.FoodDay(date: $0.date, calories: $0.calories) },
            weights: weights.map { WeeklyReviewCalculator.WeightDay(date: $0.date, weightKg: $0.weightKg) })
    }

    private var macroSplit: [Double] {
        [profile.proteinPercent, profile.carbsPercent, profile.fatPercent]
    }

    private func setMacroSplit(_ split: [Double]) {
        guard split != macroSplit else { return }
        profile.proteinPercent = split[0]
        profile.carbsPercent = split[1]
        profile.fatPercent = split[2]
    }

    private func macroBinding(_ index: Int) -> Binding<Double> {
        Binding {
            macroSplit[index]
        } set: { newValue in
            setMacroSplit(NutritionCalculator.rebalancedMacros(macroSplit, changing: index, to: newValue))
        }
    }

    var body: some View {
        @Bindable var profile = profile
        NavigationStack {
            Form {
                Section("Profile") {
                    NavigationLink {
                        ProfileEditorView()
                    } label: {
                        LabeledContent("Body & goals") {
                            Text("\(units.weightString(kg: currentKg)) → \(units.weightString(kg: profile.goalWeightKg))")
                        }
                    }
                    Picker("Units", selection: $profile.unitSystem) {
                        ForEach(UnitSystem.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Appearance", selection: $appearanceRaw) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                }

                Section {
                    LabeledContent("Maintenance (TDEE)", value: "\(Int(profile.tdee(currentWeightKg: currentKg).rounded())) kcal")
                    LabeledContent("Daily target", value: "\(profile.calorieTarget(currentWeightKg: currentKg)) kcal")
                    Toggle("Set target manually", isOn: Binding(
                        get: { profile.customCalorieTarget != nil },
                        set: { on in
                            profile.customCalorieTarget = on ? profile.calorieTarget(currentWeightKg: currentKg) : nil
                        }))
                    if profile.customCalorieTarget != nil {
                        Stepper(value: Binding(get: { profile.customCalorieTarget ?? 0 },
                                               set: { profile.customCalorieTarget = $0 }),
                                in: 1000...5000, step: 50) {
                            Text("Custom target: \(profile.customCalorieTarget ?? 0) kcal")
                        }
                    }
                } header: {
                    Text("Calories")
                } footer: {
                    Text("The target updates automatically as your weight changes, unless you set it manually.")
                }

                Section {
                    if let estimate = maintenanceEstimate {
                        let suggested = estimate.suggestedTarget(weeklyLossKg: profile.weeklyLossKg, sex: profile.sex)
                        let formula = Int(profile.tdee(currentWeightKg: currentKg).rounded())
                        LabeledContent("Measured maintenance", value: "\(estimate.maintenanceKcal) kcal")
                        LabeledContent("Formula estimate", value: "\(formula) kcal")
                        LabeledContent("Suggested target", value: "\(suggested) kcal")
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(Color.secondary)
                            Text("Based on \(estimate.daysLogged) logged days and \(estimate.weighIns) weigh-ins over the last \(estimate.windowDays) days: you averaged \(Int(estimate.meanIntakeKcal.rounded())) kcal and your weight moved \(units.weightString(kg: estimate.weeklyWeightChangeKg, decimals: 2, signed: true)) a week. Confidence: \(estimate.confidence.rawValue).")
                                .font(.footnote)
                                .foregroundStyle(Color.secondary)
                        }
                        if suggested != profile.calorieTarget(currentWeightKg: currentKg) {
                            Button {
                                profile.customCalorieTarget = suggested
                                try? context.save()
                            } label: {
                                Label("Use \(suggested) kcal as my target", systemImage: "checkmark.circle")
                            }
                        } else {
                            Label("Your current target already matches", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Color.green)
                        }
                    } else {
                        Text("Needs at least \(AdaptiveTargetCalculator.minimumDaysLogged) logged days and \(AdaptiveTargetCalculator.minimumWeighIns) weigh-ins spread over two weeks or more, within the last \(AdaptiveTargetCalculator.windowDays) days.")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                } header: {
                    Text("Adaptive target")
                } footer: {
                    Text("The formula is a starting guess. Measured maintenance uses what you actually ate and what the scale actually did.")
                }

                Section {
                    MacroSlider(name: "Protein", value: macroBinding(0), color: .blue)
                    MacroSlider(name: "Carbs", value: macroBinding(1), color: .orange)
                    MacroSlider(name: "Fat", value: macroBinding(2), color: .pink)
                    let m = profile.macroTargets(currentWeightKg: currentKg)
                    LabeledContent("Daily grams", value: "P \(Int(m.protein)) · C \(Int(m.carbs)) · F \(Int(m.fat))")
                } header: {
                    Text("Macro split")
                } footer: {
                    Text("Moving one slider rebalances the other two so the split stays at 100%. Higher protein helps keep muscle while losing fat.")
                }
                .onAppear { setMacroSplit(NutritionCalculator.normalizedMacros(macroSplit)) }

                Section {
                    if !HealthKitManager.isAvailable {
                        Text("Apple Health isn't available on this device.")
                            .foregroundStyle(Color.secondary)
                    } else {
                        Toggle("Sync with Apple Health", isOn: $healthEnabled)
                        if healthEnabled {
                            Picker("Count active energy", selection: $healthCreditPercent) {
                                Text("Off").tag(0)
                                Text("Half").tag(50)
                                Text("All").tag(100)
                            }
                            Button {
                                runHealthImport(force: true)
                            } label: {
                                HStack {
                                    Label("Import now", systemImage: "arrow.down.circle")
                                    Spacer()
                                    if healthBusy { ProgressView() }
                                }
                            }
                            .disabled(healthBusy)
                            if let last = HealthSettings.lastImport {
                                LabeledContent("Last import", value: last.formatted(date: .abbreviated, time: .shortened))
                            }
                        }
                        if let healthStatus {
                            Text(healthStatus)
                                .font(.footnote)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Reads weight, steps, active energy, resting heart rate and sleep; writes your weigh-ins and logged calories. Counting active energy adds a share of what your watch reports to the daily budget. Watches tend to overestimate, so Half is the safer choice.")
                }

                Section("Water") {
                    Stepper(value: $profile.waterGoalMl, in: 1000...5000, step: 250) {
                        LabeledContent("Daily goal", value: units.volumeString(ml: profile.waterGoalMl))
                    }
                }

                Section {
                    Toggle("Morning weigh-in", isOn: $profile.weighInReminderEnabled)
                    if profile.weighInReminderEnabled {
                        Picker("Time", selection: $profile.weighInReminderHour) {
                            ForEach(5..<12, id: \.self) { hour in
                                Text(hourLabel(hour)).tag(hour)
                            }
                        }
                    }
                    Toggle("Meal logging reminders", isOn: $profile.mealReminderEnabled)
                    Toggle("Water reminders", isOn: $profile.waterReminderEnabled)
                    if notificationsDenied {
                        Text("Notifications are turned off for this app. Enable them in iOS Settings to receive reminders.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Reminders")
                }

                Section("Data") {
                    Button {
                        exportData()
                    } label: {
                        Label("Export as CSV", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset all data", systemImage: "trash")
                    }
                }

                Section {
                    Text("Calorie and macro targets use the Mifflin-St Jeor equation and standard activity multipliers. They are estimates for healthy adults. Talk to a doctor before starting a diet if you are pregnant, under 18, or have a medical condition.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Delete every log, plan and setting? This cannot be undone.", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) { resetAll() }
            }
            .sheet(isPresented: $showExport) {
                ExportSheet(urls: exportURLs)
            }
            .onChange(of: healthEnabled) { _, on in
                if on { runHealthImport(force: true) } else { healthStatus = nil }
            }
            .onChange(of: profile.weighInReminderEnabled) { _, _ in reminderChanged() }
            .onChange(of: profile.weighInReminderHour) { _, _ in reminderChanged() }
            .onChange(of: profile.mealReminderEnabled) { _, _ in reminderChanged() }
            .onChange(of: profile.waterReminderEnabled) { _, _ in reminderChanged() }
            .onDisappear { try? context.save() }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        let date = Calendar.current.date(from: comps) ?? .now
        return date.formatted(.dateTime.hour())
    }

    private func runHealthImport(force: Bool) {
        healthBusy = true
        healthStatus = "Connecting to Health…"
        Task { @MainActor in
            defer { healthBusy = false }
            do {
                try await HealthKitManager.shared.requestAuthorization()
                await HealthKitManager.shared.refreshToday()
                if let summary = await HealthKitManager.shared.importIfDue(into: context, force: force) {
                    healthStatus = summary.description + "."
                } else if let error = HealthKitManager.shared.lastError {
                    healthStatus = error
                } else {
                    healthStatus = "Connected."
                }
            } catch {
                healthStatus = error.localizedDescription
            }
        }
    }

    private func reminderChanged() {
        let anyOn = profile.weighInReminderEnabled || profile.mealReminderEnabled || profile.waterReminderEnabled
        Task { @MainActor in
            if anyOn {
                let granted = await NotificationManager.requestAuthorization()
                notificationsDenied = !granted
            }
            NotificationManager.sync(with: profile)
        }
    }

    private func exportData() {
        var urls: [URL] = []
        if let u = try? DataExporter.exportWeights(weights) { urls.append(u) }
        if let u = try? DataExporter.exportFoodLog(foodLogs) { urls.append(u) }
        if let u = try? DataExporter.exportVitals(vitals) { urls.append(u) }
        exportURLs = urls
        showExport = true
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        guard let items = try? context.fetch(FetchDescriptor<T>()) else { return }
        for item in items { context.delete(item) }
    }

    private func resetAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let context = self.context
        dismiss()
        // Let the sheet finish dismissing so nothing on screen still reads the profile being deleted.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            deleteAll(WeightEntry.self, in: context)
            deleteAll(FoodLogEntry.self, in: context)
            deleteAll(VitalsEntry.self, in: context)
            deleteAll(WaterEntry.self, in: context)
            deleteAll(MealPlanEntry.self, in: context)
            deleteAll(SavedMeal.self, in: context)
            deleteAll(FoodItem.self, in: context)
            deleteAll(Recipe.self, in: context)
            deleteAll(UserProfile.self, in: context)
            try? context.save()
            SeedData.seedIfNeeded(context: context)
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
                            Label(url.lastPathComponent, systemImage: "doc.text")
                        }
                    }
                } footer: {
                    Text("Each file opens in any spreadsheet app. Share to Files, Mail or AirDrop.")
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
