import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var step = 0
    @ScaledMetric(relativeTo: .largeTitle) private var welcomeIconSize: CGFloat = 72
    @ScaledMetric(relativeTo: .largeTitle) private var targetSize: CGFloat = 56
    @State private var name = ""
    @State private var sex: BiologicalSex = .female
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var unitSystem: UnitSystem = .metric
    @State private var heightCm: Double = 170
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 7
    @State private var currentWeight: Double = 80
    /// No goal is chosen for the person: they pick what they want, and type a goal weight only to lose.
    @State private var goal: WeightGoal?
    @State private var goalWeight: Double?
    @State private var activity: ActivityLevel = .light
    @State private var rate: WeeklyGoalRate = .steady
    @State private var healthStatus: String?
    @State private var readingHealth = false

    private let totalSteps = 5

    private var units: Units { Units(system: unitSystem) }

    private var resolvedHeightCm: Double {
        unitSystem == .metric ? heightCm : Units.cm(feet: heightFeet, inches: heightInches)
    }
    private var currentKg: Double { units.kg(fromDisplayWeight: currentWeight) }
    private var goalKg: Double? { goalWeight.map { units.kg(fromDisplayWeight: $0) } }
    private var losing: Bool { goal == .lose }

    private var goalIsBelowCurrent: Bool {
        guard let goalKg else { return false }
        return goalKg > 30 && goalKg < currentKg
    }

    private var canContinue: Bool {
        switch step {
        case 1: return resolvedHeightCm > 100 && resolvedHeightCm < 250
        case 2:
            guard currentKg > 30, let goal else { return false }
            return !goal.needsGoalWeight || goalIsBelowCurrent
        default: return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .padding(.horizontal)
                .padding(.top)

            #if os(macOS)
            Group {
                switch step {
                case 0: welcome
                case 1: aboutYou
                case 2: weights
                case 3: lifestyle
                default: summary
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #else
            TabView(selection: $step) {
                welcome.tag(0)
                aboutYou.tag(1)
                weights.tag(2)
                lifestyle.tag(3)
                summary.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: step)
            #endif

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .buttonStyle(.bordered)
                }
                Spacer()
                Button(step == totalSteps - 1 ? "Start my journey" : "Continue") {
                    if step == totalSteps - 1 {
                        finish()
                    } else {
                        step += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canContinue)
            }
            .padding()
        }
        .readableWidth()
        .onChange(of: unitSystem) { _, newValue in
            // Convert the numbers in the fields so the user does not have to retype them.
            let other = Units(system: newValue == .metric ? .imperial : .metric)
            let cKg = other.kg(fromDisplayWeight: currentWeight)
            currentWeight = (Units(system: newValue).weightValue(kg: cKg) * 10).rounded() / 10
            goalWeight = goalWeight.map { (Units(system: newValue).weightValue(kg: other.kg(fromDisplayWeight: $0)) * 10).rounded() / 10 }
            if newValue == .imperial {
                let inches = heightCm * Units.inchPerCm
                heightFeet = Int(inches / 12)
                heightInches = Int((inches - Double(heightFeet) * 12).rounded())
            } else {
                heightCm = Units.cm(feet: heightFeet, inches: heightInches).rounded()
            }
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "figure.walk.motion")
                .font(.system(size: welcomeIconSize))
                .foregroundStyle(Color.accentColor)
            Text("Welcome to Stride")
                .font(.largeTitle.bold())
            Text("Track your weight, calories, vitals and meals in one place. Answer a few questions and we'll build a plan that fits you.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 32)
            Spacer()
            RestoreBackupButton()
                .buttonStyle(.bordered)
            Text("Your data stays on this device.")
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        }
        .padding()
    }

    private var aboutYou: some View {
        Form {
            if HealthKitManager.isAvailable {
                Section {
                    Button {
                        Task { await fillFromHealth() }
                    } label: {
                        HStack {
                            Label("Fill in from Apple Health", systemImage: "heart.text.square")
                            if readingHealth {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(readingHealth)
                    .accessibilityIdentifier("fillFromHealth")
                } footer: {
                    Text(healthStatus ?? String(localized: "Uses your height, date of birth, sex and latest weight. You can change anything afterwards."))
                }
            }
            Section {
                TextField("Name (optional)", text: $name)
                Picker("Sex", selection: $sex) {
                    ForEach(BiologicalSex.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                DatePicker("Date of birth", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
            } header: {
                Text("About you")
            } footer: {
                Text("Sex, age and height are only used to estimate how many calories your body uses.")
            }
            Section("Units") {
                Picker("Units", selection: $unitSystem) {
                    ForEach(UnitSystem.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section("Height") {
                if unitSystem == .metric {
                    HStack {
                        TextField("Height", value: $heightCm, format: .number)
                            .strideKeyboard(.decimalPad)
                        Text("cm").foregroundStyle(Color.secondary)
                    }
                } else {
                    HStack {
                        Picker("Feet", selection: $heightFeet) {
                            ForEach(3..<8, id: \.self) { Text("\($0) ft").tag($0) }
                        }
                        Picker("Inches", selection: $heightInches) {
                            ForEach(0..<12, id: \.self) { Text("\($0) in").tag($0) }
                        }
                    }
                    #if os(macOS)
                    .pickerStyle(.menu)
                    #else
                    .pickerStyle(.wheel)
                    #endif
                    .frame(height: 120)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var weights: some View {
        Form {
            Section("What would you like to do?") {
                ForEach(WeightGoal.allCases) { option in
                    Button {
                        goal = option
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label).foregroundStyle(Color.primary)
                                Text(option.detail).font(.footnote).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            if goal == option {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .accessibilityIdentifier("goal-\(option.rawValue)")
                    .accessibilityAddTraits(goal == option ? .isSelected : [])
                }
            }
            Section("Where you are") {
                HStack {
                    Text("Current weight")
                    Spacer()
                    TextField("Weight", value: $currentWeight, format: .number.precision(.fractionLength(0...1)))
                        .strideKeyboard(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text(units.weightUnit).foregroundStyle(Color.secondary)
                }
            }
            if losing {
                Section("Where you're going") {
                    HStack {
                        Text("Goal weight")
                        Spacer()
                        TextField("Goal", value: $goalWeight, format: .number.precision(.fractionLength(0...1)))
                            .strideKeyboard(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                            .accessibilityIdentifier("goalWeightField")
                        Text(units.weightUnit).foregroundStyle(Color.secondary)
                    }
                    if let goalKg, goalKg >= currentKg, currentKg > 0 {
                        Text("To lose weight, choose a goal below your current weight. To stay where you are, pick “Keep my weight steady”.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            Section {
                let bmi = NutritionCalculator.bmi(weightKg: currentKg, heightCm: resolvedHeightCm)
                LabeledContent("Current BMI", value: String(format: "%.1f · %@", bmi, NutritionCalculator.bmiCategory(bmi)))
                if losing, let goalKg {
                    let goalBmi = NutritionCalculator.bmi(weightKg: goalKg, heightCm: resolvedHeightCm)
                    LabeledContent("Goal BMI", value: String(format: "%.1f · %@", goalBmi, NutritionCalculator.bmiCategory(goalBmi)))
                }
            } footer: {
                Text("BMI is a rough guide only. A healthy range is 18.5–24.9.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var lifestyle: some View {
        Form {
            Section("Activity level") {
                ForEach(ActivityLevel.allCases) { level in
                    Button {
                        activity = level
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.label).foregroundStyle(Color.primary)
                                Text(level.detail).font(.footnote).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            if activity == level {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            if losing {
                Section {
                    Picker("Weekly goal", selection: $rate) {
                        ForEach(WeeklyGoalRate.allCases) { r in
                            Text("\(r.label) · \(units.weightString(kg: r.rawValue, decimals: 2))/week").tag(r)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("How fast?")
                } footer: {
                    Text("Slower is easier to stick to and keeps more muscle. Most people do best at 0.5 kg (about 1 lb) a week.")
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var summary: some View {
        let age = NutritionCalculator.age(birthDate: birthDate)
        let bmr = NutritionCalculator.bmr(sex: sex, weightKg: currentKg, heightCm: resolvedHeightCm, age: age)
        let tdee = NutritionCalculator.tdee(bmr: bmr, activity: activity)
        // Worked out the way the new profile will: a deficit to lose, otherwise maintenance.
        let target = losing
            ? NutritionCalculator.dailyCalorieTarget(tdee: tdee, weeklyLossKg: rate.rawValue, sex: sex)
            : MaintenanceCalculator.calorieTarget(tdee: tdee, sex: sex)
        // The same split a new profile starts with, so these grams match Today's.
        let macros = NutritionCalculator.macroGrams(calories: target, proteinPercent: 30, carbsPercent: 40, fatPercent: 30)
        let goalDate = losing ? goalKg.flatMap {
            NutritionCalculator.projectedGoalDate(currentKg: currentKg, goalKg: $0, weeklyLossKg: rate.rawValue)
        } : nil
        let atFloor = losing && target == NutritionCalculator.calorieFloor(for: sex)

        return ScrollView {
            VStack(spacing: 16) {
                Text("Your plan")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 4) {
                    Text(Energy.number(target))
                        .font(.system(size: targetSize, weight: .bold, design: .rounded).monospacedDigit())
                    Text("calories per day")
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity)
                .card()

                StatGrid {
                    StatTile(title: "You use now", value: "\(Energy.string(tdee))", subtitle: "on a typical day", systemImage: "flame.fill", tint: .orange)
                    if losing {
                        StatTile(title: "Daily gap", value: "\(Energy.string(max(Int(tdee.rounded()) - target, 0)))", subtitle: "less than you use", systemImage: "arrow.down.right", tint: .green)
                    } else if goal == .steady {
                        StatTile(title: "Weight to hold", value: units.weightString(kg: currentKg), subtitle: "within a small range", systemImage: "equal.circle.fill", tint: .green)
                    } else {
                        StatTile(title: "Starting weight", value: units.weightString(kg: currentKg), subtitle: "no goal weight", systemImage: "scalemass.fill", tint: .indigo)
                    }
                    StatTile(title: "Protein", value: "\(NutrientText.grams(macros.protein)) g", subtitle: "30% of calories", systemImage: "p.circle.fill", tint: .blue)
                    StatTile(title: "Carbs · Fat", value: "\(NutrientText.grams(macros.carbs)) · \(NutrientText.grams(macros.fat)) g", subtitle: "40% · 30%", systemImage: "chart.pie.fill", tint: .pink)
                }

                if let goalDate, let goalKg {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Rough goal date", systemImage: "flag.checkered")
                            .font(.headline)
                        Text("Around \(goalDate.approximateDateLabel())")
                            .font(.title3.weight(.semibold))
                        Text("Losing \(units.weightString(kg: currentKg - goalKg)) at about \(units.weightString(kg: rate.rawValue, decimals: 2)) a week. Real progress is rarely a straight line, and that's normal.")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }

                if atFloor {
                    Label("We've capped your target at \(Energy.string(target)), the lowest we recommend without medical supervision. Your loss may be a little slower than chosen.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                }

                Text("You can change any of this later in Settings.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
            .padding()
        }
    }

    private func fillFromHealth() async {
        readingHealth = true
        defer { readingHealth = false }
        do {
            let details = try await HealthKitManager.shared.profileDetails()
            apply(details)
            healthStatus = details.isEmpty
                ? String(localized: "Nothing found in Apple Health. Fill in the details below.")
                : String(localized: "Filled in from Apple Health. Check the details below and the weights on the next step.")
        } catch {
            healthStatus = error.localizedDescription
        }
    }

    private func apply(_ details: HealthProfileDetails) {
        if let birthDate = details.birthDate, birthDate < .now { self.birthDate = birthDate }
        if let sex = details.sex { self.sex = sex }
        if let cm = details.heightCm, (100...250).contains(cm) {
            heightCm = cm.rounded()
            let inches = cm * Units.inchPerCm
            heightFeet = Int(inches / 12)
            heightInches = min(Int((inches - Double(heightFeet) * 12).rounded()), 11)
        }
        if let kg = details.weightKg, (30...400).contains(kg) {
            // Only the current weight: the goal is the person's to choose, not a suggested loss.
            currentWeight = (units.weightValue(kg: kg) * 10).rounded() / 10
        }
    }

    private func finish() {
        let profile = UserProfile(name: name.trimmingCharacters(in: .whitespaces),
                                  sex: sex,
                                  birthDate: birthDate,
                                  heightCm: resolvedHeightCm,
                                  startWeightKg: currentKg,
                                  goalWeightKg: losing ? goalKg ?? currentKg : currentKg,
                                  activityLevel: activity,
                                  weeklyLossKg: rate.rawValue,
                                  unitSystem: unitSystem)
        // Keeping steady or just tracking runs in maintenance mode: the target is maintenance
        // calories and there's no goal weight to count down to.
        if !losing { profile.startMaintenance(atKg: currentKg) }
        context.insert(profile)
        context.insert(WeightEntry(date: .now, weightKg: currentKg, note: WeightEntry.startingWeightNote))
        context.saveReportingFailure()
        // New profiles start with a short Today screen and a forgiving streak; both can be changed.
        let defaults = UserDefaults.standard
        defaults.set(TodayLayout.starter.storage, forKey: TodayLayoutEditor.storageKey)
        defaults.set(true, forKey: StreakSettings.graceDayKey)
    }
}
