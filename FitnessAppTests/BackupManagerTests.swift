import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class BackupManagerTests: XCTestCase {
    /// A context only weakly references its container, so keep each one alive until the test ends.
    private var containers: [ModelContainer] = []

    override func tearDown() async throws {
        containers.removeAll()
        try await super.tearDown()
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppStore.schema,
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        containers.append(container)
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
        food.micros.calcium = 50
        food.barcode = "123"
        food.servingPresets = [ServingPreset(label: "cup", servings: 2)]
        context.insert(food)

        let log = FoodLogEntry(date: Date(timeIntervalSince1970: 1_700_000_100), mealType: .lunch,
                               foodName: "Oats", servings: 1.5, servingDescription: "40 g", calories: 225,
                               protein: 7, carbs: 40, fat: 4, foodItemID: food.uuid, fiber: 6)
        log.caffeine = 12
        log.micros.iron = 3
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
        // Compare everything except the timestamp, whose encoded length varies from run to run.
        var a = original, b = restored
        a.createdAt = .distantPast
        b.createdAt = .distantPast
        XCTAssertEqual(try BackupManager.encode(a), try BackupManager.encode(b))

        XCTAssertNotNil(restored.profile)
        XCTAssertEqual(restored.weights.count, 1)
        XCTAssertEqual(restored.weights.first?.photo, Data([1, 2, 3]))
        XCTAssertEqual(restored.foods.first?.servingPresets.count, 1)
        XCTAssertEqual(restored.foodLogs.first?.caffeine, 12)
        XCTAssertEqual(restored.foodLogs.first?.micros?.iron, 3)
        XCTAssertEqual(restored.foods.first?.micros?.calcium, 50)
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
        XCTAssertEqual(restored.profile?.values["customCalorieTarget"] as? Int, 2100)
        XCTAssertEqual(restored.profile?.values["dayCloseReminderHour"] as? Int, 20)
        XCTAssertEqual(restored.profile?.values["sodiumLimitMg"] as? Double, 2300)
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

    private func makeProfile() -> UserProfile {
        UserProfile(name: "", sex: .female, birthDate: .now, heightCm: 170, startWeightKg: 80, goalWeightKg: 70,
                    activityLevel: .light, weeklyLossKg: 0.5, unitSystem: .metric)
    }

    func testBackupFieldsCoverEveryProfileProperty() throws {
        let entity = try XCTUnwrap(AppStore.schema.entitiesByName["UserProfile"])
        let stored = Set(entity.attributes.map(\.name))
        let keys = UserProfile.backupFields.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "A key is listed twice in UserProfile.backupFields")
        XCTAssertEqual(stored.subtracting(keys), [], "UserProfile properties missing from UserProfile.backupFields")
        XCTAssertEqual(Set(keys).subtracting(stored), [], "UserProfile.backupFields lists properties that don't exist")
    }

    func testOptionalSettingsAreListedAsOptional() {
        // A property that can be nil needs `.optional`, so nil is written as null and old backups migrate.
        let profile = makeProfile()
        for field in UserProfile.backupFields {
            let isOptional = Mirror(reflecting: field.read(profile)).displayStyle == .optional
            XCTAssertEqual(field.isOptional, isOptional, "\(field.key) should use .\(isOptional ? "optional" : "value")")
        }
    }

    func testEveryProfileSettingRoundTrips() throws {
        let source = makeProfile()
        let original = ProfileRecord(source)
        let data = try JSONEncoder().encode(original)
        let target = makeProfile()
        try JSONDecoder().decode(ProfileRecord.self, from: data).apply(to: target)
        XCTAssertEqual(try JSONEncoder().encode(ProfileRecord(target)), data)
    }

    func testRestoresTrainingDaysAndMealSlots() throws {
        let source = try makeContext()
        try populate(source)
        let profile = try XCTUnwrap(source.fetch(FetchDescriptor<UserProfile>()).first)
        let override = Date(timeIntervalSince1970: 1_700_000_000)
        profile.mealSlotsJSON = #"["Breakfast","Lunch"]"#
        profile.trainingDaysEnabled = true
        profile.trainingWeekdayMask = 21
        profile.trainingFromWorkouts = true
        profile.trainingBonusKcal = 300
        profile.trainingCarbShift = 15
        profile.dayTypeOverrideDay = override
        profile.dayTypeOverrideIsTraining = true
        try source.save()

        let data = try BackupManager.encode(BackupManager.makeBackup(context: source))
        let target = try makeContext()
        try BackupManager.restore(BackupManager.decode(data), mode: .replace, context: target)

        let restored = try XCTUnwrap(target.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(restored.mealSlotsJSON, #"["Breakfast","Lunch"]"#)
        XCTAssertTrue(restored.trainingDaysEnabled)
        XCTAssertEqual(restored.trainingWeekdayMask, 21)
        XCTAssertTrue(restored.trainingFromWorkouts)
        XCTAssertEqual(restored.trainingBonusKcal, 300)
        XCTAssertEqual(restored.trainingCarbShift, 15)
        XCTAssertEqual(restored.dayTypeOverrideDay, override)
        XCTAssertTrue(restored.dayTypeOverrideIsTraining)
    }

    // MARK: Format versions

    /// A profile as format 1 wrote it: every setting except the ones that were nil, which were left out.
    private func version1Backup(withTrainingDays: Bool) throws -> Data {
        var profile: [String: Any] = [
            "name": "Sam", "sexRaw": "male", "birthDate": -878_000_000.0, "heightCm": 181.0,
            "startWeightKg": 95.0, "goalWeightKg": 80.0, "activityLevelRaw": "moderate", "weeklyLossKg": 0.75,
            "unitSystemRaw": "imperial", "waterGoalMl": 3000.0, "maintenanceBandKg": 1.5,
            "weeklyBudgetEnabled": true, "proteinPercent": 35.0, "carbsPercent": 35.0, "fatPercent": 30.0,
            "weightUnitRaw": "lb", "startDate": 780_000_000.0, "weighInReminderEnabled": true,
            "weighInReminderHour": 6, "waterReminderEnabled": false, "mealReminderEnabled": true,
            "proteinReminderEnabled": false, "pauseRemindersOnDietBreak": false, "medicationEnabled": false,
            "medicationName": "", "medicationDoseMg": 0.0, "medicationIntervalDays": 7,
            "medicationReminderEnabled": false, "medicationReminderHour": 9,
            "fiberTargetG": 30.0
        ]
        if withTrainingDays {
            profile["mealSlotsJSON"] = #"["Breakfast","Lunch"]"#
            profile["trainingDaysEnabled"] = true
            profile["trainingWeekdayMask"] = 21
            profile["trainingFromWorkouts"] = false
            profile["trainingBonusKcal"] = 300
            profile["trainingCarbShift"] = 15
            profile["dayTypeOverrideIsTraining"] = false
        }
        let none: [Any] = []
        let file: [String: Any] = ["version": 1, "createdAt": 780_000_000.0, "appVersion": "1.0", "profile": profile,
                                   "weights": none, "foods": none, "foodLogs": none, "vitals": none,
                                   "water": none, "recipes": none, "mealPlan": none, "savedMeals": none,
                                   "fasts": none, "exercise": none, "batches": none, "checkIns": none,
                                   "doses": none]
        return try JSONSerialization.data(withJSONObject: file)
    }

    /// A profile with every optional setting filled in, so a restore that clears them shows.
    private func profileWithEverythingSet(in context: ModelContext) -> UserProfile {
        let profile = makeProfile()
        profile.name = "Old"
        profile.customCalorieTarget = 1800
        profile.maintenanceStartedAt = .now
        profile.maintenanceWeightKg = 70
        profile.dietBreakStart = .now
        profile.dietBreakEnd = .now.addingTimeInterval(86_400 * 7)
        profile.sodiumLimitMg = 2000
        profile.dayCloseReminderHour = 21
        profile.medicationStartDate = .now
        profile.dayTypeOverrideDay = .now
        profile.dayTypeOverrideIsTraining = true
        profile.trainingDaysEnabled = true
        profile.trainingBonusKcal = 400
        context.insert(profile)
        return profile
    }

    func testBackupsAreWrittenAsTheCurrentVersionWithNilSettingsAsNull() throws {
        let context = try makeContext()
        try populate(context)
        let data = try BackupManager.encode(BackupManager.makeBackup(context: context))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, 2)
        let profile = try XCTUnwrap(json["profile"] as? [String: Any])
        XCTAssertEqual(Set(profile.keys), Set(UserProfile.backupFields.map(\.key)))
        XCTAssertTrue(profile["fiberTargetG"] is NSNull)
        XCTAssertEqual(profile["sodiumLimitMg"] as? Double, 2300)
    }

    func testVersion1BackupClearsTheSettingsItLeftOut() throws {
        let context = try makeContext()
        let profile = profileWithEverythingSet(in: context)
        let file = try BackupManager.decode(version1Backup(withTrainingDays: true))
        XCTAssertEqual(file.version, BackupManager.currentVersion)
        try BackupManager.restore(file, mode: .replace, context: context)

        XCTAssertEqual(profile.name, "Sam")
        XCTAssertEqual(profile.sex, .male)
        XCTAssertEqual(profile.weightUnitRaw, "lb")
        XCTAssertEqual(profile.fiberTargetG, 30)
        XCTAssertNil(profile.customCalorieTarget)
        XCTAssertNil(profile.maintenanceStartedAt)
        XCTAssertNil(profile.maintenanceWeightKg)
        XCTAssertNil(profile.dietBreakStart)
        XCTAssertNil(profile.dietBreakEnd)
        XCTAssertNil(profile.sodiumLimitMg)
        XCTAssertNil(profile.dayCloseReminderHour)
        XCTAssertNil(profile.medicationStartDate)
        XCTAssertNil(profile.dayTypeOverrideDay)
        XCTAssertFalse(profile.dayTypeOverrideIsTraining)
        XCTAssertEqual(profile.mealSlotsJSON, #"["Breakfast","Lunch"]"#)
        XCTAssertEqual(profile.trainingWeekdayMask, 21)
        XCTAssertEqual(profile.trainingBonusKcal, 300)
    }

    func testVersion1BackupFromBeforeTrainingDaysKeepsThem() throws {
        let context = try makeContext()
        let profile = profileWithEverythingSet(in: context)
        let override = try XCTUnwrap(profile.dayTypeOverrideDay)
        try BackupManager.restore(BackupManager.decode(version1Backup(withTrainingDays: false)),
                                  mode: .replace, context: context)

        XCTAssertEqual(profile.name, "Sam")
        XCTAssertNil(profile.customCalorieTarget)
        XCTAssertTrue(profile.trainingDaysEnabled)
        XCTAssertEqual(profile.trainingBonusKcal, 400)
        XCTAssertEqual(profile.dayTypeOverrideDay, override)
        XCTAssertTrue(profile.dayTypeOverrideIsTraining)
        XCTAssertEqual(profile.mealSlotsJSON, "")
    }

    func testVersion1BackupIntoAnEmptyStoreCreatesTheProfile() throws {
        let context = try makeContext()
        try BackupManager.restore(BackupManager.decode(version1Backup(withTrainingDays: true)),
                                  mode: .replace, context: context)
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(profile.name, "Sam")
        XCTAssertEqual(profile.heightCm, 181)
        XCTAssertEqual(profile.birthDate, Date(timeIntervalSinceReferenceDate: -878_000_000))
        XCTAssertEqual(profile.waterGoalMl, 3000)
        XCTAssertNil(profile.customCalorieTarget)
    }

    func testCurrentBackupWithoutANewerSettingLeavesItAlone() throws {
        // Stands in for a backup made before a setting was added: its key is missing, not null.
        let source = try makeContext()
        try populate(source)
        let data = try BackupManager.encode(BackupManager.makeBackup(context: source))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var profileJSON = try XCTUnwrap(json["profile"] as? [String: Any])
        profileJSON["proteinReminderEnabled"] = nil
        profileJSON["sodiumLimitMg"] = nil
        profileJSON["customCalorieTarget"] = NSNull()
        json["profile"] = profileJSON

        let target = try makeContext()
        let profile = profileWithEverythingSet(in: target)
        profile.proteinReminderEnabled = true
        try BackupManager.restore(BackupManager.decode(JSONSerialization.data(withJSONObject: json)),
                                  mode: .replace, context: target)

        XCTAssertEqual(profile.name, "Sam")
        XCTAssertTrue(profile.proteinReminderEnabled)
        XCTAssertEqual(profile.sodiumLimitMg, 2000)
        XCTAssertNil(profile.customCalorieTarget)
        XCTAssertNil(profile.dayTypeOverrideDay)
    }
}
