import SwiftUI

/// Fibre, sugar and sodium for a day, against the user's optional goals.
struct NutrientRow: View {
    var fiber: Double
    var sugar: Double
    var sodium: Double
    var profile: UserProfile

    var body: some View {
        AdaptiveStack(spacing: 8) {
            NutrientPill(name: "Fibre", value: fiber, unit: "g", goal: profile.fiberTargetG, isMinimum: true)
            NutrientPill(name: "Sugar", value: sugar, unit: "g", goal: profile.sugarLimitG, isMinimum: false)
            NutrientPill(name: "Sodium", value: sodium, unit: "mg", goal: profile.sodiumLimitMg, isMinimum: false)
        }
    }
}

/// Saturated fat, potassium and cholesterol, when turned on in Settings.
struct ExtraNutrientRow: View {
    var saturatedFat: Double
    var potassium: Double
    var cholesterol: Double
    var profile: UserProfile

    var body: some View {
        AdaptiveStack(spacing: 8) {
            NutrientPill(name: "Sat. fat", value: saturatedFat, unit: "g", goal: profile.saturatedFatLimitG, isMinimum: false)
            NutrientPill(name: "Potassium", value: potassium, unit: "mg", goal: profile.potassiumTargetMg, isMinimum: true)
            NutrientPill(name: "Cholesterol", value: cholesterol, unit: "mg", goal: profile.cholesterolLimitMg, isMinimum: false)
        }
    }
}

/// Alcohol and caffeine for a day, shown when either was logged.
struct DrinksNutrientRow: View {
    var alcohol: Double
    var caffeine: Double

    var body: some View {
        AdaptiveStack(spacing: 8) {
            if alcohol > 0 {
                NutrientPill(name: "Alcohol", value: alcohol, unit: "g", goal: nil, isMinimum: false)
                NutrientPill(name: "Drinks", value: Alcohol.standardDrinks(grams: alcohol), unit: "", goal: nil,
                             isMinimum: false, fractionDigits: 1)
            }
            if caffeine > 0 {
                NutrientPill(name: "Caffeine", value: caffeine, unit: "mg", goal: Caffeine.dailyLimitMg, isMinimum: false)
            }
        }
    }
}

/// Whether saturated fat, potassium and cholesterol are shown and tracked.
enum ExtraNutrients {
    static let storageKey = "showExtraNutrients"
}

struct NutrientPill: View {
    var name: String
    var value: Double
    var unit: String
    var goal: Double?
    /// A minimum (fibre) is good once reached; a limit (sugar, sodium) is a warning once passed.
    var isMinimum: Bool
    var fractionDigits = 0

    private var tint: Color {
        guard let goal, goal > 0 else { return .secondary }
        if isMinimum { return value >= goal ? .green : .secondary }
        return value > goal ? .orange : .secondary
    }

    private var text: String {
        let amount = value.formatted(.number.precision(.fractionLength(0...fractionDigits)))
        guard let goal, goal > 0 else { return unit.isEmpty ? amount : "\(amount) \(unit)" }
        return "\(amount) / \(Int(goal.rounded())) \(unit)"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
            Text(text)
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(tint == .secondary ? Color.primary : tint)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) \(text)")
    }
}

/// Settings for the optional fibre, sugar and sodium goals.
struct NutrientGoalsSection: View {
    @Bindable var profile: UserProfile
    @AppStorage(ExtraNutrients.storageKey) private var showExtras = false

    var body: some View {
        Section {
            goal("Fibre goal", value: $profile.fiberTargetG, suggested: 30, range: 5...80, step: 1, unit: "g")
            goal("Sugar limit", value: $profile.sugarLimitG, suggested: 50, range: 5...200, step: 5, unit: "g")
            goal("Sodium limit", value: $profile.sodiumLimitMg, suggested: 2300, range: 500...5000, step: 100, unit: "mg")
            Toggle("Saturated fat, potassium and cholesterol", isOn: $showExtras)
            if showExtras {
                goal("Saturated fat limit", value: $profile.saturatedFatLimitG, suggested: 20, range: 5...60, step: 1, unit: "g")
                goal("Potassium goal", value: $profile.potassiumTargetMg, suggested: 3500, range: 1000...6000, step: 100, unit: "mg")
                goal("Cholesterol limit", value: $profile.cholesterolLimitMg, suggested: 300, range: 100...600, step: 25, unit: "mg")
            }
        } header: {
            Text("Other nutrients")
        } footer: {
            Text("Shown in the food diary for foods that list them. Common guidance is at least 30 g of fibre, under 50 g of sugar and under 2,300 mg of sodium a day, and, if you track them, under about 20 g of saturated fat and 300 mg of cholesterol with around 3,500 mg of potassium; ask your doctor if you're managing blood pressure, cholesterol or glucose.")
        }
    }

    @ViewBuilder
    private func goal(_ title: String, value: Binding<Double?>, suggested: Double,
                      range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        Toggle(title, isOn: Binding(get: { value.wrappedValue != nil },
                                    set: { value.wrappedValue = $0 ? suggested : nil }))
        if let current = value.wrappedValue {
            Stepper(value: Binding(get: { current }, set: { value.wrappedValue = $0 }), in: range, step: step) {
                Text("\(Int(current)) \(unit) a day")
                    .monospacedDigit()
            }
        }
    }
}
