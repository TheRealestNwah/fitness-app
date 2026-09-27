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
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create the data store: \(error)")
        }
        // "-resetData" / "-demoData" launch arguments (UI tests, demos).
        DemoData.applyLaunchArguments(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
