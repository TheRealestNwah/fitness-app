import SwiftUI

/// The maintenance band with a marker for the 7-day trend, and whether it has drifted out.
struct MaintenanceBandView: View {
    var trendKg: Double
    var centerKg: Double
    var bandKg: Double
    var units: Units

    private var status: MaintenanceStatus {
        MaintenanceCalculator.status(trendKg: trendKg, centerKg: centerKg, bandKg: bandKg)
    }

    private var message: String {
        switch status {
        case .inBand:
            return "7-day average \(units.weightString(kg: trendKg)), inside your band."
        case .above(let over):
            return "7-day average is \(units.weightString(kg: over)) above your band. Trim a little for a week or two."
        case .below(let under):
            return "7-day average is \(units.weightString(kg: under)) below your band. You can eat a bit more."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let position = MaintenanceCalculator.position(trendKg: trendKg, centerKg: centerKg, bandKg: bandKg)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.green.opacity(0.2))
                    Circle()
                        .fill(status.isOutside ? Color.orange : Color.green)
                        .frame(width: 14, height: 14)
                        .offset(x: max(0, geo.size.width * position - 7))
                }
            }
            .frame(height: 14)
            HStack {
                Text(units.weightString(kg: centerKg - bandKg))
                Spacer()
                Text("Holding \(units.weightString(kg: centerKg))")
                Spacer()
                Text(units.weightString(kg: centerKg + bandKg))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Color.secondary)
            Label(message, systemImage: status.isOutside ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(status.isOutside ? Color.orange : Color.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Settings for maintenance mode.
struct MaintenanceSection: View {
    @Bindable var profile: UserProfile
    var currentKg: Double

    var body: some View {
        Section {
            Toggle("Maintenance mode", isOn: Binding(
                get: { profile.isMaintaining },
                set: { on in
                    if on { profile.startMaintenance(atKg: min(currentKg, profile.goalWeightKg)) } else { profile.endMaintenance() }
                }))
            if profile.isMaintaining {
                Stepper(value: Binding(get: { profile.maintenanceCenterKg },
                                       set: { profile.maintenanceWeightKg = $0 }),
                        in: 30...300, step: profile.units.system == .metric ? 0.5 : 1 / Units.lbPerKg) {
                    LabeledContent("Weight to hold", value: profile.units.weightString(kg: profile.maintenanceCenterKg))
                }
                Stepper(value: $profile.maintenanceBandKg, in: MaintenanceCalculator.bandRange, step: 0.5) {
                    LabeledContent("Band", value: "± \(profile.units.weightString(kg: profile.maintenanceBandKg))")
                }
            }
        } header: {
            Text("Maintenance")
        } footer: {
            Text(profile.isMaintaining
                 ? "Your calorie target is your maintenance, and Today warns you if your 7-day average drifts outside the band."
                 : "Once you reach your goal, switch to maintenance to hold your weight within a band instead of counting down.")
        }
    }
}
