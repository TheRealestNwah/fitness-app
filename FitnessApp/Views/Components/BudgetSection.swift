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
                               value: "\(start.shortDateLabel()) – \(end.addingTimeInterval(-1).shortDateLabel())")
                Button("Cancel diet break", role: .destructive) {
                    profile.dietBreakStart = nil
                    profile.dietBreakEnd = nil
                }
            } else {
                DatePicker("Diet break from", selection: $breakStart, in: Date.now.startOfDay..., displayedComponents: .date)
                Stepper(value: $breakDays, in: 7...21, step: 7) {
                    Text("For \(breakDays / 7) weeks")
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
            Text("Keeps your diary, weigh-ins, vitals and plans the same on every iPhone, iPad and Mac signed in to your Apple ID. Changes take effect the next time Stride starts. Turning it off keeps this device's copy.")
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

/// Settings for separate calorie and carb targets on training and rest days.
struct TrainingDaysSection: View {
    @Bindable var profile: UserProfile

    private var plan: TrainingPlan { profile.trainingPlan }

    var body: some View {
        Section {
            Toggle("Training and rest day targets", isOn: $profile.trainingDaysEnabled)
                .accessibilityIdentifier("trainingDaysToggle")
            if profile.trainingDaysEnabled {
                HStack {
                    ForEach(orderedWeekdays, id: \.self) { weekday in
                        let on = plan.weekdays.contains(weekday)
                        Button {
                            toggle(weekday)
                        } label: {
                            Text(Calendar.current.veryShortWeekdaySymbols[weekday - 1])
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(on ? Color.accentColor : Color.secondary.opacity(0.15), in: Circle())
                                .foregroundStyle(on ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                        .accessibilityValue(on ? "Training day" : "Rest day")
                    }
                }
                Toggle("Count logged or imported workouts", isOn: $profile.trainingFromWorkouts)
                Stepper(value: $profile.trainingBonusKcal, in: TrainingPlan.bonusRange, step: 50) {
                    LabeledContent("Training days", value: "+\(Energy.string(Double(plan.bonusKcal)))")
                }
                LabeledContent("Rest days", value: "−\(Energy.string(Double(DayTargets.restCutKcal(plan))))")
                Stepper(value: $profile.trainingCarbShift, in: TrainingPlan.carbShiftRange, step: 5) {
                    LabeledContent("Carbs on training days", value: "+\(plan.carbShiftPercent)% of calories")
                }
            }
        } header: {
            Text("Training days")
        } footer: {
            Text("Eat more on days you train and less on rest days. The rest-day cut is sized so a normal week averages out to your daily target, so your goal date doesn't change. Carbs move from fat on training days and back on rest days. If you also add exercise calories back, keep the training bonus small. You can switch today's type from the Today screen.")
        }
    }

    /// Weekdays starting from the calendar's first day.
    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    private func toggle(_ weekday: Int) {
        var copy = plan
        if copy.weekdays.contains(weekday) { copy.weekdays.remove(weekday) } else { copy.weekdays.insert(weekday) }
        profile.trainingWeekdayMask = DayTargets.weekdayMask(copy.weekdays)
    }
}
