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
        return .result(value: Int(left.rounded()),
                       dialog: left >= 0 ? "You have \(amount) left today." : "You're \(amount) over today.")
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
