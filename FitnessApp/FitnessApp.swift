import SwiftUI
import SwiftData

@main
struct FitnessApp: App {
    @UIApplicationDelegateAdaptor(StrideAppDelegate.self) private var appDelegate
    let container: ModelContainer

    init() {
        container = AppStore.container
        // "-resetData" / "-demoData" launch arguments (UI tests, demos).
        DemoData.applyLaunchArguments(context: container.mainContext)
        FeatureTips.configure()
        WatchSync.shared.start(container: container)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .appLockGate()
        }
        .modelContainer(container)
        .commands { StrideCommands() }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await BackgroundRefresh.run()
        }
    }
}

/// The one data store, shared by the app and the App Intents that Siri and Shortcuts run
/// (which can launch the app in the background without a scene).
enum AppStore {
    /// A new instance each time: a Schema shouldn't be shared between containers (tests make their own).
    static var schema: Schema { Schema(models) }

    static let models: [any PersistentModel.Type] = [
        UserProfile.self,
        WeightEntry.self,
        FoodItem.self,
        FoodLogEntry.self,
        VitalsEntry.self,
        WaterEntry.self,
        Recipe.self,
        MealPlanEntry.self,
        SavedMeal.self,
        FastingSession.self,
        ExerciseEntry.self,
    ]

    @MainActor static let container: ModelContainer = CloudSync.makeContainer(schema: schema)
}
