import SwiftUI
import SwiftData

@main
struct FitnessApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
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
        container = CloudSync.makeContainer(schema: schema)
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
