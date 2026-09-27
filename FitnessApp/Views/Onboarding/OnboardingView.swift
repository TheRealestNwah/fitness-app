import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var step = 0
    @State private var name = ""
    @State private var sex: BiologicalSex = .female
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var unitSystem: UnitSystem = .metric
    @State private var heightCm: Double = 170
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 7
    @State private var currentWeight: Double = 80
    @State private var goalWeight: Double = 70
    @State private var activity: ActivityLevel = .light
    @State private var rate: WeeklyGoalRate = .steady

    private let totalSteps = 5

    private var units: Units { Units(system: unitSystem) }

    private var resolvedHeightCm: Double {
        unitSystem == .metric ? heightCm : Units.cm(feet: heightFeet, inches: heightInches)
    }
    private var currentKg: Double { units.kg(fromDisplayWeight: currentWeight) }
    private var goalKg: Double { units.kg(fromDisplayWeight: goalWeight) }

    private var canContinue: Bool {
        switch step {
        case 1: return resolvedHeightCm > 100 && resolvedHeightCm < 250
        case 2: return currentKg > 30 && goalKg > 30 && goalKg < currentKg
        default: return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .padding(.horizontal)
                .padding(.top)

            TabView(selection: $step) {
                welcome.tag(0)
                aboutYou.tag(1)
                weights.tag(2)
                lifestyle.tag(3)
                summary.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: step)

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
        .background(Color(.systemGroupedBackground))
        .onChange(of: unitSystem) { _, newValue in
            // Convert the numbers in the fields so the user does not have to retype them.
            let other = Units(system: newValue == .metric ? .imperial : .metric)
            let cKg = other.kg(fromDisplayWeight: currentWeight)
            let gKg = other.kg(fromDisplayWeight: goalWeight)
            currentWeight = (Units(system: newValue).weightValue(kg: cKg) * 10).rounded() / 10
            goalWeight = (Units(system: newValue).weightValue(kg: gKg) * 10).rounded() / 10
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
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
            Text("Welcome to Stride")
                .font(.largeTitle.bold())
            Text("Track your weight, calories, vitals and meals in one place. Answer a few questions and we'll build a plan that fits you.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()
            Text("Your data stays on this device.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    private var aboutYou: some View {
        Form {
            Section("About you") {
                TextField("Name (optional)", text: $name)
                Picker("Sex", selection: $sex) {
                    ForEach(BiologicalSex.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                DatePicker("Date of birth", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
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
                            .keyboardType(.decimalPad)
                        Text("cm").foregroundStyle(.secondary)
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
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var weights: some View {
        Form {
            Section("Where you are") {
                HStack {
                    Text("Current weight")
                    Spacer()
                    TextField("Weight", value: $currentWeight, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text(units.weightUnit).foregroundStyle(.secondary)
                }
            }
            Section("Where you're going") {
                HStack {
                    Text("Goal weight")
                    Spacer()
                    TextField("Goal", value: $goalWeight, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text(units.weightUnit).foregroundStyle(.secondary)
                }
                if goalKg >= currentKg && currentKg > 0 {
                    Text("Your goal should be below your current weight.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            Section {
                let bmi = NutritionCalculator.bmi(weightKg: currentKg, heightCm: resolvedHeightCm)
                LabeledContent("Current BMI", value: String(format: "%.1f · %@", bmi, NutritionCalculator.bmiCategory(bmi)))
                let goalBmi = NutritionCalculator.bmi(weightKg: goalKg, heightCm: resolvedHeightCm)
                LabeledContent("Goal BMI", value: String(format: "%.1f · %@", goalBmi, NutritionCalculator.bmiCategory(goalBmi)))
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
                                Text(level.label).foregroundStyle(.primary)
                                Text(level.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if activity == level {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
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
        .scrollContentBackground(.hidden)
    }

    private var summary: some View {
        let age = NutritionCalculator.age(birthDate: birthDate)
        let bmr = NutritionCalculator.bmr(sex: sex, weightKg: currentKg, heightCm: resolvedHeightCm, age: age)
        let tdee = NutritionCalculator.tdee(bmr: bmr, activity: activity)
        let target = NutritionCalculator.dailyCalorieTarget(tdee: tdee, weeklyLossKg: rate.rawValue, sex: sex)
        let macros = NutritionCalculator.macroGrams(calories: target, proteinPercent: 30, carbsPercent: 40, fatPercent: 30)
        let goalDate = NutritionCalculator.projectedGoalDate(currentKg: currentKg, goalKg: goalKg, weeklyLossKg: rate.rawValue)
        let atFloor = target == NutritionCalculator.calorieFloor(for: sex)

        return ScrollView {
            VStack(spacing: 16) {
                Text("Your plan")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 4) {
                    Text("\(target)")
                        .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    Text("calories per day")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .card()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(title: "Maintenance", value: "\(Int(tdee.rounded())) kcal", subtitle: "what you burn now", systemImage: "flame.fill", tint: .orange)
                    StatTile(title: "Daily deficit", value: "\(max(Int(tdee.rounded()) - target, 0)) kcal", subtitle: units.weightString(kg: rate.rawValue, decimals: 2) + "/week", systemImage: "arrow.down.right", tint: .green)
                    StatTile(title: "Protein", value: "\(Int(macros.protein)) g", subtitle: "30% of calories", systemImage: "p.circle.fill", tint: .blue)
                    StatTile(title: "Carbs · Fat", value: "\(Int(macros.carbs)) · \(Int(macros.fat)) g", subtitle: "40% · 30%", systemImage: "chart.pie.fill", tint: .pink)
                }

                if let goalDate {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Projected goal date", systemImage: "flag.checkered")
                            .font(.headline)
                        Text(goalDate.formatted(date: .long, time: .omitted))
                            .font(.title3.weight(.semibold))
                        Text("Losing \(units.weightString(kg: currentKg - goalKg)) at \(units.weightString(kg: rate.rawValue, decimals: 2)) a week.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }

                if atFloor {
                    Label("We've capped your target at \(target) kcal, the lowest we recommend without medical supervision. Your loss may be a little slower than chosen.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                }

                Text("You can change any of this later in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
    }

    private func finish() {
        let profile = UserProfile(name: name.trimmingCharacters(in: .whitespaces),
                                  sex: sex,
                                  birthDate: birthDate,
                                  heightCm: resolvedHeightCm,
                                  startWeightKg: currentKg,
                                  goalWeightKg: goalKg,
                                  activityLevel: activity,
                                  weeklyLossKg: rate.rawValue,
                                  unitSystem: unitSystem)
        context.insert(profile)
        context.insert(WeightEntry(date: .now, weightKg: currentKg, note: "Starting weight"))
        try? context.save()
    }
}
