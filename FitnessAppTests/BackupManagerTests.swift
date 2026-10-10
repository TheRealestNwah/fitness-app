import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class BackupManagerTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppStore.schema,
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        return container.mainContext
    }

    private func populate(_ context: ModelContext) throws {
        let profile = UserProfile(name: "Sam", sex: .male, birthDate: Date(timeIntervalSince1970: 100_000_000),
                                  heightCm: 181, startWeightKg: 95, goalWeightKg: 80, activityLevel: .moderate,
                                  weeklyLossKg: 0.75, unitSystem: .imperial)
        profile.customCalorieTarget = 2100
        profile.sodiumLimitMg = 2300
        profile.medicationEnabled = true
        profile.medicationName = "Test"
        profile.dayCloseReminderHour = 20
        context.insert(profile)

        let weight = WeightEntry(date: Date(timeIntervalSince1970: 1_700_000_000), weightKg: 93.4, note: "morning")
        weight.photo = Data([1, 2, 3])
        weight.sourceID = "hk-1"
        context.insert(weight)

        let food = FoodItem(name: "Oats", brand: "Co", servingDescription: "40 g", calories: 150, protein: 5,
                            carbs: 27, fat: 3, fiber: 4, sugar: 1, sodium: 10, isCustom: true)
        food.potassium = 120
        food.isFavorite = true
        food.barcode = "123"
        food.servingPresets = [ServingPreset(label: "cup", servings: 2)]
        context.insert(food)

        let log = FoodLogEntry(date: Date(timeIntervalSince1970: 1_700_000_100), mealType: .lunch,
                               foodName: "Oats", servings: 1.5, servingDescription: "40 g", calories: 225,
                               protein: 7, carbs: 40, fat: 4, foodItemID: food.uuid, fiber: 6)
        log.caffeine = 12
        log.isEstimate = true
        log.photo = Data([9])
        context.insert(log)

        let vitals = VitalsEntry(date: Date(timeIntervalSince1970: 1_700_000_200))
        vitals.systolic = 120
        vitals.diastolic = 80
        vitals.sleepHours = 7.5
        vitals.note = "ok"
        context.insert(vitals)

        context.insert(WaterEntry(date: Date(timeIntervalSince1970: 1_700_000_300), amountMl: 330))

        let recipe = Recipe(name: "Bowl", mealType: .lunch, servings: 2, prepMinutes: 10,
                            ingredients: [Ingredient(name: "Rice", amount: "1 cup", calories: 200, protein: 4,
                                                     carbs: 44, fat: 1)],
                            instructions: "Cook", tags: ["quick"], isCustom: true)
        recipe.isFavorite = true
        context.insert(recipe)

        let plan = MealPlanEntry(day: Date(timeIntervalSince1970: 1_700_100_000), mealType: .dinner, title: "Bowl",
                                 servings: 2, caloriesPerServing: 300, proteinPerServing: 20,
                                 carbsPerServing: 30, fatPerServing: 8, recipeID: recipe.uuid)
        plan.isLogged = true
        context.insert(plan)

        let item = SavedMealItem(foodName: "Oats", servings: 1, servingDescription: "40 g", calories: 150,
                                 protein: 5, carbs: 27, fat: 3)
        let saved = SavedMeal(name: "Breakfast", mealType: .breakfast, items: [item])
        saved.useCount = 3
        saved.photo = Data([7, 7])
        context.insert(saved)

        let fast = FastingSession(start: Date(timeIntervalSince1970: 1_700_000_000), targetHours: 18)
        fast.end = Date(timeIntervalSince1970: 1_700_070_000)
        context.insert(fast)

        let exercise = ExerciseEntry(date: Date(timeIntervalSince1970: 1_700_000_400), activity: "Run",
                                     minutes: 30, calories: 300)
        exercise.sourceID = "w1"
        context.insert(exercise)

        let batch = MealPrepBatch(recipe: recipe, portions: 4, cookedAt: Date(timeIntervalSince1970: 1_700_000_500))
        batch.portionsLeft = 2
        context.insert(batch)

        let checkIn = MealCheckIn(day: Date(timeIntervalSince1970: 1_700_000_000), mealType: .dinner, hunger: 3, mood: 4)
        context.insert(checkIn)

        let dose = MedicationDose(date: Date(timeIntervalSince1970: 1_700_000_600), medication: "Test", doseMg: 0.5,
                                  site: .abdomenLeft, sideEffects: ["nausea"], note: "n")
        dose.healthID = "h1"
        context.insert(dose)
        try context.save()
    }

    func testRoundTripsEveryModelIntoAnEmptyStore() throws {
        let source = try makeContext()
        try populate(source)
        let original = try BackupManager.makeBackup(context: source)
        let data = try BackupManager.encode(original)

        let decoded = try BackupManager.decode(data)
        let target = try makeContext()
        try BackupManager.restore(decoded, mode: .replace, context: target)

        let restored = try BackupManager.makeBackup(context: target)
        XCTAssertEqual(try BackupManager.encode(restored).count, data.count)
        // Compare everything except the timestamp.
        var a = original, b = restored
        a.createdAt = .distantPast
        b.createdAt = .distantPast
        XCTAssertEqual(try BackupManager.encode(a), try BackupManager.encode(b))

        XCTAssertNotNil(restored.profile)
        XCTAssertEqual(restored.weights.count, 1)
        XCTAssertEqual(restored.weights.first?.photo, Data([1, 2, 3]))
        XCTAssertEqual(restored.foods.first?.servingPresets.count, 1)
        XCTAssertEqual(restored.foodLogs.first?.caffeine, 12)
        XCTAssertEqual(restored.vitals.count, 1)
        XCTAssertEqual(restored.water.count, 1)
        XCTAssertEqual(restored.recipes.first?.ingredients.count, 1)
        XCTAssertEqual(restored.mealPlan.first?.isLogged, true)
        XCTAssertEqual(restored.savedMeals.first?.photo, Data([7, 7]))
        XCTAssertEqual(restored.fasts.first?.targetHours, 18)
        XCTAssertEqual(restored.exercise.first?.sourceID, "w1")
        XCTAssertEqual(restored.batches.first?.portionsLeft, 2)
        XCTAssertEqual(restored.checkIns.first?.hunger, 3)
        XCTAssertEqual(restored.doses.first?.sideEffects, ["nausea"])
        XCTAssertEqual(restored.profile?.customCalorieTarget, 2100)
        XCTAssertEqual(restored.profile?.dayCloseReminderHour, 20)
    }

    func testReplaceUpdatesTheExistingProfileAndDropsOtherData() throws {
        let source = try makeContext()
        try populate(source)
        let backup = try BackupManager.makeBackup(context: source)

        let target = try makeContext()
        let existing = UserProfile(name: "Old", sex: .female, birthDate: .now, heightCm: 160, startWeightKg: 70,
                                   goalWeightKg: 60, activityLevel: .light, weeklyLossKg: 0.5, unitSystem: .metric)
        target.insert(existing)
        target.insert(WaterEntry(date: .now, amountMl: 100))
        try target.save()

        try BackupManager.restore(backup, mode: .replace, context: target)
        let profiles = try target.fetch(FetchDescriptor<UserProfile>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(existing.name, "Sam")
        let water = try target.fetch(FetchDescriptor<WaterEntry>())
        XCTAssertEqual(water.map(\.amountMl), [330])
    }

    func testMergeKeepsExistingDataAndSkipsDuplicates() throws {
        let source = try makeContext()
        try populate(source)
        let backup = try BackupManager.makeBackup(context: source)

        let target = try makeContext()
        target.insert(WaterEntry(date: .now, amountMl: 100))
        try target.save()

        try BackupManager.restore(backup, mode: .merge, context: target)
        try BackupManager.restore(backup, mode: .merge, context: target)
        XCTAssertEqual(try target.fetch(FetchDescriptor<WaterEntry>()).count, 2)
        XCTAssertEqual(try target.fetch(FetchDescriptor<WeightEntry>()).count, 1)
        XCTAssertEqual(try target.fetch(FetchDescriptor<FoodLogEntry>()).count, 1)
        XCTAssertEqual(try target.fetch(FetchDescriptor<UserProfile>()).count, 1)
    }

    func testNewerBackupIsRejected() throws {
        let data = Data(#"{"version": 99, "createdAt": 0, "appVersion": "9"}"#.utf8)
        XCTAssertThrowsError(try BackupManager.decode(data)) { error in
            guard case BackupError.newerVersion(let v) = error else { return XCTFail("wrong error \(error)") }
            XCTAssertEqual(v, 99)
        }
    }

    func testGarbageIsRejected() {
        XCTAssertThrowsError(try BackupManager.decode(Data("not json".utf8)))
    }

    func testSummaryCountsRecords() throws {
        let context = try makeContext()
        try populate(context)
        let summary = BackupManager.summary(of: try BackupManager.makeBackup(context: context))
        XCTAssertEqual(summary.weighIns, 1)
        XCTAssertEqual(summary.foodEntries, 1)
        XCTAssertEqual(summary.records, 13)
    }

    func testExportWritesAReadableFile() throws {
        let context = try makeContext()
        try populate(context)
        let url = try BackupManager.export(context: context, now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(url.pathExtension, "stridebackup")
        XCTAssertNoThrow(try BackupManager.decode(Data(contentsOf: url)))
    }
}
