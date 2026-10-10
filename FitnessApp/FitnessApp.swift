import SwiftUI
import SwiftData

@main
struct FitnessApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(StrideAppDelegate.self) private var appDelegate
    #endif
    let container: ModelContainer

    init() {
        container = AppStore.container
        // "-resetData" / "-demoData" launch arguments (UI tests, demos).
        DemoData.applyLaunchArguments(context: container.mainContext)
        FeatureTips.configure()
        WatchSync.shared.start(container: container)
    }

    var body: some Scene {
        WindowGroup("Stride", id: "main") {
            RootView()
                .platformWindow()
                .uiTestSizeClass()
                .appLockGate()
                .backupRestorePrompt()
        }
        .modelContainer(container)
        .commands { StrideCommands() }
        #if os(iOS)
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await BackgroundRefresh.run()
        }
        #else
        .defaultSize(width: 1150, height: 800)
        #endif

        // A recipe opened in its own window from the recipe library (iPad, Stage Manager).
        WindowGroup("Recipe", id: RecipeWindow.id, for: UUID.self) { $recipeID in
            RecipeWindow(recipeID: recipeID)
                .platformWindow()
                .appLockGate()
        }
        .modelContainer(container)
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
        MealPrepBatch.self,
        MealCheckIn.self,
        MedicationDose.self,
    ]

    @MainActor static let container: ModelContainer = CloudSync.makeContainer(schema: schema)
}
