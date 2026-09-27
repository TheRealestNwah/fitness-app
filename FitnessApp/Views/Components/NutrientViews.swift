import SwiftUI

/// Fibre, sugar and sodium for a day, against the user's optional goals.
struct NutrientRow: View {
    var fiber: Double
    var sugar: Double
    var sodium: Double
    var profile: UserProfile

    var body: some View {
        HStack(spacing: 8) {
            NutrientPill(name: "Fibre", value: fiber, unit: "g", goal: profile.fiberTargetG, isMinimum: true)
            NutrientPill(name: "Sugar", value: sugar, unit: "g", goal: profile.sugarLimitG, isMinimum: false)
            NutrientPill(name: "Sodium", value: sodium, unit: "mg", goal: profile.sodiumLimitMg, isMinimum: false)
        }
    }
}

struct NutrientPill: View {
    var name: String
    var value: Double
    var unit: String
    var goal: Double?
    /// A minimum (fibre) is good once reached; a limit (sugar, sodium) is a warning once passed.
    var isMinimum: Bool

    private var tint: Color {
        guard let goal, goal > 0 else { return .secondary }
        if isMinimum { return value >= goal ? .green : .secondary }
        return value > goal ? .orange : .secondary
    }

    private var text: String {
        let amount = "\(Int(value.rounded()))"
        guard let goal, goal > 0 else { return "\(amount) \(unit)" }
        return "\(amount) / \(Int(goal.rounded())) \(unit)"
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption2)
                .foregroundStyle(Color.secondary)
            Text(text)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(tint == .secondary ? Color.primary : tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) \(text)")
    }
}

/// Settings for the optional fibre, sugar and sodium goals.
struct NutrientGoalsSection: View {
    @Bindable var profile: UserProfile

    var body: some View {
        Section {
            goal("Fibre goal", value: $profile.fiberTargetG, suggested: 30, range: 5...80, step: 1, unit: "g")
            goal("Sugar limit", value: $profile.sugarLimitG, suggested: 50, range: 5...200, step: 5, unit: "g")
            goal("Sodium limit", value: $profile.sodiumLimitMg, suggested: 2300, range: 500...5000, step: 100, unit: "mg")
        } header: {
            Text("Other nutrients")
        } footer: {
            Text("Shown in the food diary for foods that list them. Common guidance is at least 30 g of fibre, under 50 g of sugar and under 2,300 mg of sodium a day; ask your doctor if you're managing blood pressure or glucose.")
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
