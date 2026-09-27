import SwiftUI
import SwiftData

@main
struct FitnessApp: App {
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
        }
        .modelContainer(container)
    }
}

/// The one data store, shared by the app and the App Intents that Siri and Shortcuts run
/// (which can launch the app in the background without a scene).
enum AppStore {
    static let schema = Schema([
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
    ])

    @MainActor static let container: ModelContainer = CloudSync.makeContainer(schema: schema)
}
