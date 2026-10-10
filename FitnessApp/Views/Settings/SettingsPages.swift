import SwiftUI
import SwiftData
import TipKit

/// One page of Settings, as pushed from the root list or a search result.
struct SettingsPageView: View {
    let page: SettingsPage
    /// Runs "Reset all data"; the root closes the sheet first when Settings is one.
    var resetAllData: () -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        content
            .readableWidth()
            .navigationTitle(page.title)
            .inlineNavigationTitle()
            .onDisappear { try? context.save() }
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .profile: ProfileSettingsPage()
        case .nutrition: NutritionSettingsPage()
        case .reminders: ReminderSettingsPage()
        case .healthData: HealthDataSettingsPage(resetAllData: resetAllData)
        case .privacy: Form { AppLockSection(); OnlineFoodSearchSection() }
        case .about: AboutSettingsPage()
        }
    }
}

// MARK: - Profile & goals

private struct ProfileSettingsPage: View {
    @Environment(UserProfile.self) private var profile
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @AppStorage(Appearance.storageKey) private var appearanceRaw = Appearance.system.rawValue
    @AppStorage(StreakSettings.graceDayKey) private var streakGraceDay = false

    private var units: Units { profile.units }
    private var currentKg: Double { weights.first?.weightKg ?? profile.startWeightKg }

    var body: some View {
        @Bindable var profile = profile
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
                UnitPreferenceRows(profile: profile)
                Picker("Appearance", selection: $appearanceRaw) {
                    ForEach(Appearance.allCases) { Text($0.label).tag($0.rawValue) }
                }
            }

            Section("Water") {
                Stepper(value: $profile.waterGoalMl, in: 1000...5000, step: 250) {
                    LabeledContent("Daily goal", value: units.volumeString(ml: profile.waterGoalMl))
                }
            }

            MedicationSettingsSection(profile: profile)

            Section {
                Toggle("Streak grace day", isOn: $streakGraceDay)
            } header: {
                Text("Streak")
            } footer: {
                Text("A single missed day won't break your logging streak, once a week. Two missed days in a row still start it over.")
            }
        }
    }
}

// MARK: - Nutrition & targets

private struct NutritionSettingsPage: View {
    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var foodLogs: [FoodLogEntry]

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
        Form {
            Section {
                LabeledContent("Maintenance (TDEE)", value: "\(Energy.string(profile.tdee(currentWeightKg: currentKg)))")
                LabeledContent("Daily target", value: "\(Energy.string(profile.calorieTarget(currentWeightKg: currentKg)))")
                Toggle("Set target manually", isOn: Binding(
                    get: { profile.customCalorieTarget != nil },
                    set: { on in
                        profile.customCalorieTarget = on ? profile.calorieTarget(currentWeightKg: currentKg) : nil
                    }))
                if profile.customCalorieTarget != nil {
                    Stepper(value: Binding(get: { profile.customCalorieTarget ?? 0 },
                                           set: { profile.customCalorieTarget = $0 }),
                            in: 1000...5000, step: 50) {
                        Text("Custom target: \(Energy.string(profile.customCalorieTarget ?? 0))")
                    }
                }
            } header: {
                Text("Calories")
            } footer: {
                Text("The target updates automatically as your weight changes, unless you set it manually.")
            }

            adaptiveTarget

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

            NutrientGoalsSection(profile: profile)

            MaintenanceSection(profile: profile, currentKg: currentKg)

            BudgetSection(profile: profile)

            ExerciseSection()
        }
    }

    private var adaptiveTarget: some View {
        Section {
            if let estimate = maintenanceEstimate {
                TipView(AdaptiveTargetTip())
                let suggested = estimate.suggestedTarget(weeklyLossKg: profile.weeklyLossKg, sex: profile.sex)
                let formula = Int(profile.tdee(currentWeightKg: currentKg).rounded())
                LabeledContent("Measured maintenance", value: "\(Energy.string(estimate.maintenanceKcal))")
                LabeledContent("Formula estimate", value: "\(Energy.string(formula))")
                LabeledContent("Suggested target", value: "\(Energy.string(suggested))")
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(Color.secondary)
                    Text("Based on \(estimate.daysLogged) logged days and \(estimate.weighIns) weigh-ins over the last \(estimate.windowDays) days: you averaged \(Energy.string(estimate.meanIntakeKcal)) and your weight moved \(units.weightString(kg: estimate.weeklyWeightChangeKg, decimals: 2, signed: true)) a week. Confidence: \(estimate.confidence.rawValue).")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
                if suggested != profile.calorieTarget(currentWeightKg: currentKg) {
                    Button {
                        AdaptiveTargetTip().invalidate(reason: .actionPerformed)
                        profile.customCalorieTarget = suggested
                        try? context.save()
                    } label: {
                        Label("Use \(Energy.string(suggested)) as my target", systemImage: "checkmark.circle")
                    }
                } else {
                    Label("Your current target already matches", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                }
            } else {
                TrendProgressView(title: "Your measured maintenance appears after two weeks of logging food and weighing in.",
                                  progress: TrendReadiness.maintenance(
                                    foodLogs: foodLogs.map { WeeklyReviewCalculator.FoodDay(date: $0.date, calories: $0.calories) },
                                    weights: weights.map { WeeklyReviewCalculator.WeightDay(date: $0.date, weightKg: $0.weightKg) }))
            }
        } header: {
            Text("Adaptive target")
        } footer: {
            Text("The formula is a starting guess. Measured maintenance uses what you actually ate and what the scale actually did.")
        }
    }
}

// MARK: - Reminders

private struct ReminderSettingsPage: View {
    @Environment(UserProfile.self) private var profile
    @State private var notificationsDenied = false

    var body: some View {
        @Bindable var profile = profile
        Form {
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
                Toggle("Protein check", isOn: $profile.proteinReminderEnabled)
                Toggle("Evening check-in", isOn: Binding(
                    get: { profile.dayCloseReminderHour != nil },
                    set: { profile.dayCloseReminderHour = $0 ? 20 : nil }))
                if let hour = profile.dayCloseReminderHour {
                    Picker("Check-in time", selection: Binding(get: { hour }, set: { profile.dayCloseReminderHour = $0 })) {
                        ForEach(18..<23, id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }
                }
                Toggle("Pause during diet breaks", isOn: $profile.pauseRemindersOnDietBreak)
                if notificationsDenied {
                    Text("Notifications are turned off for this app. Enable them in iOS Settings to receive reminders.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } footer: {
                Text("The weigh-in reminder skips days you've already weighed in, water reminders stop for the day once you reach your goal, and meal reminders skip meals you've already logged. The protein check comes at 5 pm when you're at least 15 g short, and the evening check-in only if dinner isn't logged. During a diet break, everything except water can pause.")
            }
        }
        .onChange(of: profile.weighInReminderEnabled) { _, _ in reminderChanged() }
        .onChange(of: profile.weighInReminderHour) { _, _ in reminderChanged() }
        .onChange(of: profile.mealReminderEnabled) { _, _ in reminderChanged() }
        .onChange(of: profile.waterReminderEnabled) { _, _ in reminderChanged() }
        .onChange(of: profile.dayCloseReminderHour) { _, _ in reminderChanged() }
        .onChange(of: profile.proteinReminderEnabled) { _, _ in reminderChanged() }
        .onChange(of: profile.pauseRemindersOnDietBreak) { _, _ in reminderChanged() }
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        let date = Calendar.current.date(from: comps) ?? .now
        return date.formatted(.dateTime.hour())
    }

    private func reminderChanged() {
        let anyOn = NotificationManager.anyReminderEnabled(profile)
        Task { @MainActor in
            if anyOn {
                let granted = await NotificationManager.requestAuthorization()
                notificationsDenied = !granted
            }
            NotificationManager.sync(with: profile)
        }
    }
}

// MARK: - Health & data

private struct HealthDataSettingsPage: View {
    var resetAllData: () -> Void

    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var foodLogs: [FoodLogEntry]
    @Query private var vitals: [VitalsEntry]

    @AppStorage(HealthSettings.enabledKey) private var healthEnabled = false
    @AppStorage(HealthSettings.creditPercentKey) private var healthCreditPercent = 0
    @AppStorage(CycleCalculator.enabledKey) private var cycleAware = false
    @State private var healthStatus: String?
    @State private var healthBusy = false
    @State private var showResetConfirm = false
    @State private var exportURLs: [URL] = []
    @State private var showExport = false

    private var currentKg: Double { weights.first?.weightKg ?? profile.startWeightKg }

    var body: some View {
        Form {
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
                    Toggle("Cycle-aware weight", isOn: $cycleAware)
                    if let healthStatus {
                        Text(healthStatus)
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                }
            } header: {
                Text("Apple Health")
            } footer: {
                Text("Reads weight, steps, active energy, resting heart rate and sleep; writes your weigh-ins, water, and logged calories, macros, fibre, sugar and sodium. Counting active energy adds a share of what your watch reports to the daily budget. Watches tend to overestimate, so Half is the safer choice. Cycle-aware weight reads your cycle from Health to mark likely water-retention days on the weight chart and leave them out of plateau checks.")
            }

            ReviewSummarySection()

            ICloudSyncSection()

            Section("Data") {
                Button {
                    exportData()
                } label: {
                    Label("Export and share", systemImage: "square.and.arrow.up")
                }
                ImportCSVButton()
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset all data", systemImage: "trash")
                }
            }
        }
        .alert("Reset all data?", isPresented: $showResetConfirm) {
            Button("Delete everything", role: .destructive) { resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every weigh-in, food log, vitals reading, meal plan, recipe and setting will be deleted from this device and you'll start setup again. This can't be undone.")
        }
        .strideSheet(isPresented: $showExport) {
            ExportSheet(urls: exportURLs)
        }
        .onChange(of: healthEnabled) { _, on in
            if on { runHealthImport(force: true) } else { healthStatus = nil }
        }
        .onChange(of: cycleAware) { _, on in
            Task {
                if on { try? await HealthKitManager.shared.requestCycleAccess() }
                await HealthKitManager.shared.refreshCycle()
            }
        }
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

    private func exportData() {
        let units = profile.units
        var urls: [URL] = []
        if let u = try? DataExporter.exportWeights(weights) { urls.append(u) }
        if let u = try? DataExporter.exportFoodLog(foodLogs) { urls.append(u) }
        if let u = try? DataExporter.exportVitals(vitals) { urls.append(u) }
        let review = WeeklyReviewCalculator.review(
            foodLogs: foodLogs.map { WeeklyReviewCalculator.FoodDay(date: $0.date, calories: $0.calories) },
            weights: weights.map { WeeklyReviewCalculator.WeightDay(date: $0.date, weightKg: $0.weightKg) },
            budget: profile.calorieTarget(currentWeightKg: currentKg),
            plannedWeeklyLossKg: profile.weeklyLossKg)
        let streak = NutritionCalculator.streak(logDates: foodLogs.map(\.date) + weights.map(\.date))
        if let u = ReportRenderer.weeklySummaryImage(review: review, streak: streak, units: units) { urls.insert(u, at: 0) }
        let report = HealthReport.make(
            weights: weights.map { (date: $0.date, kg: $0.weightKg) },
            vitals: vitals.map { .init(date: $0.date, systolic: $0.systolic, diastolic: $0.diastolic,
                                       heartRate: $0.restingHeartRate, glucose: $0.bloodGlucose, waistCm: $0.waistCm) })
        if let u = ReportRenderer.doctorReportPDF(report: report, profile: profile) { urls.insert(u, at: min(1, urls.count)) }
        exportURLs = urls
        showExport = true
    }
}

// MARK: - About

private struct AboutSettingsPage: View {
    @State private var tipsWillReset = UserDefaults.standard.bool(forKey: FeatureTips.resetOnLaunchKey)

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                Button {
                    FeatureTips.resetOnNextLaunch()
                    tipsWillReset = true
                } label: {
                    Label(tipsWillReset ? "Tips will show next time you open the app" : "Show feature tips again",
                          systemImage: "lightbulb")
                }
                .disabled(tipsWillReset)
            }

            Section {
                LabeledContent("Version", value: version)
                Text("Calorie and macro targets use the Mifflin-St Jeor equation and standard activity multipliers. They are estimates for healthy adults. Talk to a doctor before starting a diet if you are pregnant, under 18, or have a medical condition.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            } header: {
                Text("About Stride")
            }
        }
    }
}

// MARK: - Online food search

private struct OnlineFoodSearchSection: View {
    @AppStorage(OnlineFoodSearch.enabledKey) private var enabled = true
    @AppStorage(OnlineFoodSearch.usdaKeyKey) private var usdaKey = ""

    var body: some View {
        Section {
            Toggle("Search food databases online", isOn: $enabled)
            if enabled {
                TextField("USDA API key (optional)", text: $usdaKey)
                    .withoutAutocapitalization()
                    .autocorrectionDisabled()
                Link("Get a free USDA key", destination: FoodDataCentralClient.signupURL)
            }
        } header: {
            Text("Online food search")
        } footer: {
            Text("When a food isn't saved on your device, Stride can look it up on USDA FoodData Central and Open Food Facts. The words you search for are sent to those services, nothing else. Without your own USDA key, a shared one is used and may run out at busy times.")
        }
    }
}
