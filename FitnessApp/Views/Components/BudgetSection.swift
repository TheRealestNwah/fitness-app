import SwiftUI

/// Settings for weekly calorie budgeting and diet breaks.
struct BudgetSection: View {
    @Bindable var profile: UserProfile

    @State private var breakStart = Date.now
    @State private var breakDays = 14

    var body: some View {
        Section {
            Toggle("Budget by the week", isOn: $profile.weeklyBudgetEnabled)
                .disabled(profile.isMaintaining)
            if let start = profile.dietBreakStart, let end = profile.dietBreakEnd, end > .now {
                LabeledContent("Diet break",
                               value: "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.addingTimeInterval(-1).formatted(.dateTime.month(.abbreviated).day()))")
                Button("Cancel diet break", role: .destructive) {
                    profile.dietBreakStart = nil
                    profile.dietBreakEnd = nil
                }
            } else {
                DatePicker("Diet break from", selection: $breakStart, in: Date.now.startOfDay..., displayedComponents: .date)
                Stepper(value: $breakDays, in: 7...21, step: 7) {
                    Text("For \(breakDays / 7) week\(breakDays == 7 ? "" : "s")")
                }
                Button("Schedule diet break") {
                    profile.dietBreakStart = breakStart.startOfDay
                    profile.dietBreakEnd = breakStart.startOfDay.adding(days: breakDays)
                }
            }
        } header: {
            Text("Flexible budget")
        } footer: {
            Text("Budget by the week lets lighter days bank calories for later ones; days you don't log count as on target. A diet break sets your target to maintenance for one to three weeks and moves your goal date back to match, so it isn't counted as falling behind.")
        }
    }
}

/// Turn iCloud sync on or off; applies the next time the app starts.
struct ICloudSyncSection: View {
    @AppStorage(CloudSync.enabledKey) private var requested = false

    private var status: String {
        if CloudSync.isActive { return "Syncing with iCloud." }
        if let problem = CloudSync.problem { return problem }
        return requested ? "Starts the next time you open Stride." : "Data stays on this device."
    }

    var body: some View {
        Section {
            Toggle("Sync with iCloud", isOn: $requested)
            Text(status)
                .font(.footnote)
                .foregroundStyle(CloudSync.problem == nil ? Color.secondary : Color.orange)
        } header: {
            Text("iCloud")
        } footer: {
            Text("Keeps your diary, weigh-ins, vitals and plans the same on every iPhone and iPad signed in to your Apple ID. Changes take effect the next time Stride starts. Turning it off keeps this device's copy.")
        }
    }
}

/// Weight and energy units, beyond the metric/imperial switch.
struct UnitPreferenceRows: View {
    @Bindable var profile: UserProfile
    @AppStorage(EnergyUnit.storageKey) private var energyUnit = EnergyUnit.kcal.rawValue

    var body: some View {
        Picker("Weight in", selection: $profile.weightUnitRaw) {
            Text("Match units").tag("")
            ForEach(WeightUnit.allCases) { Text($0.label).tag($0.rawValue) }
        }
        Picker("Energy in", selection: $energyUnit) {
            ForEach(EnergyUnit.allCases) { Text($0.label).tag($0.rawValue) }
        }
    }
}
