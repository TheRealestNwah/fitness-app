import AppIntents
import Foundation

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Adds water to today's total in Stride. Leave the amount empty to log one glass.")

    @Parameter(title: "Amount")
    var amount: Measurement<UnitVolume>?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) of water")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppStore.container.mainContext
        let total = try QuickLog.water(ml: amount?.converted(to: .milliliters).value, context: context)
        let units = QuickLog.units(in: context)
        return .result(dialog: "Logged. That's \(units.volumeString(ml: total)) today.")
    }
}

struct LogWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Weight"
    static var description = IntentDescription("Adds a weigh-in to Stride.")

    @Parameter(title: "Weight")
    var weight: Measurement<UnitMass>

    static var parameterSummary: some ParameterSummary {
        Summary("Log a weight of \(\.$weight)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppStore.container.mainContext
        let kg = weight.converted(to: .kilograms).value
        try QuickLog.weight(kg: kg, context: context)
        return .result(dialog: "Logged \(QuickLog.units(in: context).weightString(kg: kg)).")
    }
}

struct CaloriesLeftIntent: AppIntent {
    static var title: LocalizedStringResource = "Calories Left"
    static var description = IntentDescription("How many calories are left in today's budget.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let left = try QuickLog.caloriesLeft(context: AppStore.container.mainContext)
        let amount = Energy.string(abs(left))
        let dialog: IntentDialog
        if left >= 0 {
            dialog = "You have \(amount) left today."
        } else {
            dialog = "You're \(amount) over today."
        }
        return .result(value: Int(left.rounded()), dialog: dialog)
    }
}

struct StrideShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogWaterIntent(),
                    phrases: ["Log water in \(.applicationName)", "Add a glass of water in \(.applicationName)"],
                    shortTitle: "Log Water", systemImageName: "drop.fill")
        AppShortcut(intent: LogWeightIntent(),
                    phrases: ["Log my weight in \(.applicationName)", "Weigh in with \(.applicationName)"],
                    shortTitle: "Log Weight", systemImageName: "scalemass.fill")
        AppShortcut(intent: CaloriesLeftIntent(),
                    phrases: ["How many calories do I have left in \(.applicationName)", "Calories left in \(.applicationName)"],
                    shortTitle: "Calories Left", systemImageName: "flame.fill")
    }
}

/// Lets a Focus hide calorie and weight numbers while it's on. When the Focus ends the system runs the
/// filter again with the default (off) value, which turns the mode back off.
struct HideNumbersFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Hide calorie and weight numbers"
    static var description = IntentDescription("Hides calorie and weight numbers in Stride while this Focus is on.")

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Hide calorie and weight numbers")
    }

    @Parameter(title: "Hide numbers", default: false)
    var hideNumbers: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Hide numbers: \(\.$hideNumbers)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        NumberPrivacy.shared.focus = hideNumbers
        let context = AppStore.container.mainContext
        if let profile = QuickLog.profile(in: context) {
            NotificationManager.sync(with: profile)
        }
        return .result()
    }
}
