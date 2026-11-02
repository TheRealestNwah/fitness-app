import Foundation
import SwiftData
import UniformTypeIdentifiers

/// A whole-app backup: every model, profile and photo in one versioned JSON file.
struct BackupFile: Codable {
    var version: Int
    var createdAt: Date
    var appVersion: String
    var profile: ProfileRecord?
    var weights: [WeightRecord] = []
    var foods: [FoodRecord] = []
    var foodLogs: [FoodLogRecord] = []
    var vitals: [VitalsRecord] = []
    var water: [WaterRecord] = []
    var recipes: [RecipeRecord] = []
    var mealPlan: [MealPlanRecord] = []
    var savedMeals: [SavedMealRecord] = []
    var fasts: [FastRecord] = []
    var exercise: [ExerciseRecord] = []
    var batches: [BatchRecord] = []
    var checkIns: [CheckInRecord] = []
    var doses: [DoseRecord] = []
}

enum BackupError: LocalizedError {
    case newerVersion(Int)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .newerVersion(let v):
            return String(localized: "This backup was made by a newer version of Stride (format \(v)). Update the app and try again.")
        case .unreadable:
            return String(localized: "This file isn't a Stride backup, or it's damaged.")
        }
    }
}

enum BackupManager {
    /// Bump when the file format changes in a way older apps can't read.
    /// 2: the profile writes nil settings as `null` instead of leaving them out (ADR 0012).
    static let currentVersion = 2
    static let fileExtension = "stridebackup"

    static var contentType: UTType {
        UTType("com.stride.FitnessApp.backup") ?? .data
    }

    /// What a backup holds, for the confirmation dialog.
    struct Summary: Equatable {
        var createdAt: Date
        var weighIns: Int
        var foodEntries: Int
        var records: Int
    }

    enum Mode { case replace, merge }

    // MARK: Export

    @MainActor
    static func makeBackup(context: ModelContext, now: Date = .now) throws -> BackupFile {
        func all<T: PersistentModel>(_ type: T.Type) throws -> [T] { try context.fetch(FetchDescriptor<T>()) }
        let info = Bundle.main.infoDictionary
        var file = BackupFile(version: currentVersion, createdAt: now,
                              appVersion: info?["CFBundleShortVersionString"] as? String ?? "")
        file.profile = try all(UserProfile.self).first.map(ProfileRecord.init)
        file.weights = try all(WeightEntry.self).map(WeightRecord.init)
        file.foods = try all(FoodItem.self).map(FoodRecord.init)
        file.foodLogs = try all(FoodLogEntry.self).map(FoodLogRecord.init)
        file.vitals = try all(VitalsEntry.self).map(VitalsRecord.init)
        file.water = try all(WaterEntry.self).map(WaterRecord.init)
        file.recipes = try all(Recipe.self).map(RecipeRecord.init)
        file.mealPlan = try all(MealPlanEntry.self).map(MealPlanRecord.init)
        file.savedMeals = try all(SavedMeal.self).map(SavedMealRecord.init)
        file.fasts = try all(FastingSession.self).map(FastRecord.init)
        file.exercise = try all(ExerciseEntry.self).map(ExerciseRecord.init)
        file.batches = try all(MealPrepBatch.self).map(BatchRecord.init)
        file.checkIns = try all(MealCheckIn.self).map(CheckInRecord.init)
        file.doses = try all(MedicationDose.self).map(DoseRecord.init)
        return file
    }

    @MainActor
    static func export(context: ModelContext, now: Date = .now) throws -> URL {
        let data = try encode(makeBackup(context: context, now: now))
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Stride backup \(stamp.string(from: now)).\(fileExtension)")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func encode(_ file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(file)
    }

    // MARK: Import

    /// Decodes a backup, rejecting files from a newer format than this app understands
    /// and bringing older ones up to the current format.
    static func decode(_ data: Data) throws -> BackupFile {
        struct Header: Decodable { var version: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else { throw BackupError.unreadable }
        if header.version > currentVersion { throw BackupError.newerVersion(header.version) }
        guard var file = try? JSONDecoder().decode(BackupFile.self, from: data) else { throw BackupError.unreadable }
        file.profile?.upgrade(fromVersion: header.version)
        file.version = currentVersion
        return file
    }

    static func summary(of file: BackupFile) -> Summary {
        let total = file.weights.count + file.foods.count + file.foodLogs.count + file.vitals.count
            + file.water.count + file.recipes.count + file.mealPlan.count + file.savedMeals.count
            + file.fasts.count + file.exercise.count + file.batches.count + file.checkIns.count + file.doses.count
        return Summary(createdAt: file.createdAt, weighIns: file.weights.count,
                       foodEntries: file.foodLogs.count, records: total)
    }

    /// Replace wipes today's data first (the profile is updated in place); merge adds only what isn't there yet.
    @MainActor
    static func restore(_ file: BackupFile, mode: Mode, context: ModelContext) throws {
        if mode == .replace {
            try deleteAll(context: context)
        }
        let existingProfile = try context.fetch(FetchDescriptor<UserProfile>()).first
        if let record = file.profile {
            if let existingProfile {
                if mode == .replace { record.apply(to: existingProfile) }
            } else {
                context.insert(record.makeModel())
            }
        }
        try insert(file.weights, existing: ids(WeightEntry.self, context), mode, context)
        try insert(file.foods, existing: ids(FoodItem.self, context), mode, context)
        try insert(file.foodLogs, existing: ids(FoodLogEntry.self, context), mode, context)
        try insert(file.vitals, existing: ids(VitalsEntry.self, context), mode, context)
        try insert(file.water, existing: ids(WaterEntry.self, context), mode, context)
        try insert(file.recipes, existing: ids(Recipe.self, context), mode, context)
        try insert(file.mealPlan, existing: ids(MealPlanEntry.self, context), mode, context)
        try insert(file.savedMeals, existing: ids(SavedMeal.self, context), mode, context)
        try insert(file.fasts, existing: ids(FastingSession.self, context), mode, context)
        try insert(file.exercise, existing: ids(ExerciseEntry.self, context), mode, context)
        try insert(file.batches, existing: ids(MealPrepBatch.self, context), mode, context)
        try insert(file.checkIns, existing: ids(MealCheckIn.self, context), mode, context)
        try insert(file.doses, existing: ids(MedicationDose.self, context), mode, context)
        try context.save()
    }

    @MainActor
    private static func insert<R: BackupRecord>(_ records: [R], existing: Set<UUID>, _ mode: Mode,
                                                _ context: ModelContext) throws {
        for record in records where mode == .replace || !existing.contains(record.uuid) {
            context.insert(record.makeModel())
        }
    }

    @MainActor
    private static func ids<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) throws -> Set<UUID> {
        var found = Set<UUID>()
        for model in try context.fetch(FetchDescriptor<T>()) {
            if let uuid = (model as? any Identified)?.uuid { found.insert(uuid) }
        }
        return found
    }

    @MainActor
    private static func deleteAll(context: ModelContext) throws {
        try context.delete(model: WeightEntry.self)
        try context.delete(model: FoodItem.self)
        try context.delete(model: FoodLogEntry.self)
        try context.delete(model: VitalsEntry.self)
        try context.delete(model: WaterEntry.self)
        try context.delete(model: Recipe.self)
        try context.delete(model: MealPlanEntry.self)
        try context.delete(model: SavedMeal.self)
        try context.delete(model: FastingSession.self)
        try context.delete(model: ExerciseEntry.self)
        try context.delete(model: MealPrepBatch.self)
        try context.delete(model: MealCheckIn.self)
        try context.delete(model: MedicationDose.self)
    }
}

/// Models that carry a stable `uuid`.
protocol Identified { var uuid: UUID { get } }
extension WeightEntry: Identified {}
extension FoodItem: Identified {}
extension FoodLogEntry: Identified {}
extension VitalsEntry: Identified {}
extension WaterEntry: Identified {}
extension Recipe: Identified {}
extension MealPlanEntry: Identified {}
extension SavedMeal: Identified {}
extension FastingSession: Identified {}
extension ExerciseEntry: Identified {}
extension MealPrepBatch: Identified {}
extension MealCheckIn: Identified {}
extension MedicationDose: Identified {}

protocol BackupRecord: Codable {
    associatedtype Model: PersistentModel
    var uuid: UUID { get }
    func makeModel() -> Model
}

// MARK: - Records

/// One `UserProfile` setting as a backup writes and reads it. The list lives on the profile
/// (`UserProfile.backupFields`), so the file format follows the model instead of a hand-copied record.
struct ProfileField {
    struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    let key: String
    /// The setting can be nil. Version 1 backups left nil settings out of the file.
    let isOptional: Bool
    /// The setting's nil, typed for `write`; nil for a setting that can't be nil.
    let nilValue: Any?
    let read: (UserProfile) -> Any
    let write: (Any, UserProfile) -> Void
    let encode: (Any, inout KeyedEncodingContainer<Key>) throws -> Void
    let decode: (KeyedDecodingContainer<Key>) throws -> Any

    /// A setting that always has a value.
    static func value<V: Codable>(_ key: String, _ path: ReferenceWritableKeyPath<UserProfile, V>) -> ProfileField {
        ProfileField(key: key, isOptional: false, nilValue: nil,
                     read: { $0[keyPath: path] },
                     write: { value, profile in
                         if let value = value as? V { profile[keyPath: path] = value }
                     },
                     encode: { value, container in
                         if let value = value as? V { try container.encode(value, forKey: Key(key)) }
                     },
                     decode: { container in try container.decode(V.self, forKey: Key(key)) })
    }

    /// A setting that can be nil. Nil is written as `null`, so a missing key only ever means
    /// "this backup predates the setting".
    static func optional<V: Codable>(_ key: String, _ path: ReferenceWritableKeyPath<UserProfile, V?>) -> ProfileField {
        ProfileField(key: key, isOptional: true, nilValue: (nil as V?) as Any,
                     read: { $0[keyPath: path] as Any },
                     write: { value, profile in
                         if let value = value as? V? { profile[keyPath: path] = value }
                     },
                     encode: { value, container in
                         if let value = value as? V {
                             try container.encode(value, forKey: Key(key))
                         } else {
                             try container.encodeNil(forKey: Key(key))
                         }
                     },
                     decode: { container in try container.decodeIfPresent(V.self, forKey: Key(key)) as Any })
    }
}

/// The profile's settings in a backup, keyed as in `UserProfile.backupFields`.
/// A key that's missing (a backup made before that setting existed) leaves the profile's value alone.
struct ProfileRecord: Codable {
    private(set) var values: [String: Any] = [:]

    init(_ profile: UserProfile) {
        for field in UserProfile.backupFields {
            values[field.key] = field.read(profile)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ProfileField.Key.self)
        for field in UserProfile.backupFields where container.contains(ProfileField.Key(field.key)) {
            values[field.key] = try field.decode(container)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ProfileField.Key.self)
        for field in UserProfile.backupFields {
            if let value = values[field.key] { try field.encode(value, &container) }
        }
    }

    /// Reads an older file's profile as the current format.
    ///
    /// Version 1 left nil settings out, so there a missing optional key means nil, not "unknown".
    /// The exception is `dayTypeOverrideDay` in files from before training days were backed up (#407):
    /// those have no `dayTypeOverrideIsTraining` either, and the override is left alone.
    mutating func upgrade(fromVersion version: Int) {
        guard version < 2 else { return }
        let hasTrainingDays = values["dayTypeOverrideIsTraining"] != nil
        for field in UserProfile.backupFields where field.isOptional && values[field.key] == nil {
            if field.key == "dayTypeOverrideDay" && !hasTrainingDays { continue }
            values[field.key] = field.nilValue
        }
    }

    func apply(to profile: UserProfile) {
        for field in UserProfile.backupFields {
            if let value = values[field.key] { field.write(value, profile) }
        }
    }

    func makeModel() -> UserProfile {
        let p = UserProfile(name: "", sex: .female, birthDate: Date(timeIntervalSince1970: 0), heightCm: 170,
                            startWeightKg: 80, goalWeightKg: 70, activityLevel: .light,
                            weeklyLossKg: 0.5, unitSystem: .metric)
        apply(to: p)
        return p
    }
}

struct WeightRecord: BackupRecord {
    var uuid: UUID
    var date: Date
    var weightKg: Double
    var note: String
    var sourceID: String?
    var photo: Data?

    init(_ e: WeightEntry) {
        uuid = e.uuid; date = e.date; weightKg = e.weightKg; note = e.note
        sourceID = e.sourceID; photo = e.photo
    }

    func makeModel() -> WeightEntry {
        let e = WeightEntry(date: date, weightKg: weightKg, note: note)
        e.uuid = uuid; e.sourceID = sourceID; e.photo = photo
        return e
    }
}

struct FoodRecord: BackupRecord {
    var uuid: UUID
    var name: String
    var brand: String
    var servingDescription: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double
    var saturatedFat: Double
    var potassium: Double
    var cholesterol: Double
    var alcohol: Double
    var caffeine: Double
    /// Optional so backups made before vitamins and minerals were tracked still restore.
    var micros: Micronutrients?
    var isFavorite: Bool
    var isCustom: Bool
    var lastUsed: Date?
    var useCount: Int
    var barcode: String?
    var servingPresets: [ServingPreset]
    var lastServings: Double?

    init(_ f: FoodItem) {
        uuid = f.uuid; name = f.name; brand = f.brand; servingDescription = f.servingDescription
        calories = f.calories; protein = f.protein; carbs = f.carbs; fat = f.fat
        fiber = f.fiber; sugar = f.sugar; sodium = f.sodium; saturatedFat = f.saturatedFat
        potassium = f.potassium; cholesterol = f.cholesterol; alcohol = f.alcohol; caffeine = f.caffeine
        micros = f.micros.hasData ? f.micros : nil
        isFavorite = f.isFavorite; isCustom = f.isCustom; lastUsed = f.lastUsed; useCount = f.useCount
        barcode = f.barcode; servingPresets = f.servingPresets; lastServings = f.lastServings
    }

    func makeModel() -> FoodItem {
        let f = FoodItem(name: name, brand: brand, servingDescription: servingDescription, calories: calories,
                         protein: protein, carbs: carbs, fat: fat, fiber: fiber, sugar: sugar, sodium: sodium,
                         isCustom: isCustom)
        f.uuid = uuid; f.saturatedFat = saturatedFat; f.potassium = potassium; f.cholesterol = cholesterol
        f.alcohol = alcohol; f.caffeine = caffeine; f.isFavorite = isFavorite; f.lastUsed = lastUsed
        f.useCount = useCount; f.barcode = barcode; f.servingPresets = servingPresets
        f.lastServings = lastServings; f.micros = micros ?? Micronutrients()
        return f
    }
}

struct FoodLogRecord: BackupRecord {
    var uuid: UUID
    var date: Date
    var mealTypeRaw: String
    var foodName: String
    var servings: Double
    var servingDescription: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double
    var saturatedFat: Double
    var potassium: Double
    var cholesterol: Double
    var alcohol: Double
    var caffeine: Double
    /// Optional so backups made before vitamins and minerals were tracked still restore.
    var micros: Micronutrients?
    var foodItemID: UUID?
    var photo: Data?
    var isEstimate: Bool

    init(_ e: FoodLogEntry) {
        uuid = e.uuid; date = e.date; mealTypeRaw = e.mealTypeRaw; foodName = e.foodName
        servings = e.servings; servingDescription = e.servingDescription
        calories = e.calories; protein = e.protein; carbs = e.carbs; fat = e.fat
        fiber = e.fiber; sugar = e.sugar; sodium = e.sodium; saturatedFat = e.saturatedFat
        potassium = e.potassium; cholesterol = e.cholesterol; alcohol = e.alcohol; caffeine = e.caffeine
        micros = e.micros.hasData ? e.micros : nil
        foodItemID = e.foodItemID; photo = e.photo; isEstimate = e.isEstimate
    }

    func makeModel() -> FoodLogEntry {
        let e = FoodLogEntry(date: date, mealType: .snack, foodName: foodName, servings: servings,
                             servingDescription: servingDescription, calories: calories, protein: protein,
                             carbs: carbs, fat: fat, foodItemID: foodItemID, fiber: fiber, sugar: sugar,
                             sodium: sodium)
        e.uuid = uuid; e.mealTypeRaw = mealTypeRaw; e.saturatedFat = saturatedFat; e.potassium = potassium
        e.cholesterol = cholesterol; e.alcohol = alcohol; e.caffeine = caffeine
        e.photo = photo; e.isEstimate = isEstimate; e.micros = micros ?? Micronutrients()
        return e
    }
}

struct VitalsRecord: BackupRecord {
    var uuid: UUID
    var date: Date
    var systolic: Int?
    var diastolic: Int?
    var restingHeartRate: Int?
    var bodyFatPercent: Double?
    var waistCm: Double?
    var hipCm: Double?
    var chestCm: Double?
    var sleepHours: Double?
    var bloodGlucose: Double?
    var note: String
    var sourceID: String?

    init(_ v: VitalsEntry) {
        uuid = v.uuid; date = v.date; systolic = v.systolic; diastolic = v.diastolic
        restingHeartRate = v.restingHeartRate; bodyFatPercent = v.bodyFatPercent
        waistCm = v.waistCm; hipCm = v.hipCm; chestCm = v.chestCm
        sleepHours = v.sleepHours; bloodGlucose = v.bloodGlucose; note = v.note; sourceID = v.sourceID
    }

    func makeModel() -> VitalsEntry {
        let v = VitalsEntry(date: date)
        v.uuid = uuid; v.systolic = systolic; v.diastolic = diastolic; v.restingHeartRate = restingHeartRate
        v.bodyFatPercent = bodyFatPercent; v.waistCm = waistCm; v.hipCm = hipCm; v.chestCm = chestCm
        v.sleepHours = sleepHours; v.bloodGlucose = bloodGlucose; v.note = note; v.sourceID = sourceID
        return v
    }
}

struct WaterRecord: BackupRecord {
    var uuid: UUID
    var date: Date
    var amountMl: Double

    init(_ w: WaterEntry) { uuid = w.uuid; date = w.date; amountMl = w.amountMl }

    func makeModel() -> WaterEntry {
        let w = WaterEntry(date: date, amountMl: amountMl)
        w.uuid = uuid
        return w
    }
}

struct RecipeRecord: BackupRecord {
    var uuid: UUID
    var name: String
    var mealTypeRaw: String
    var servings: Int
    var prepMinutes: Int
    var ingredients: [Ingredient]
    var instructions: String
    var tags: [String]
    var isFavorite: Bool
    var isCustom: Bool

    init(_ r: Recipe) {
        uuid = r.uuid; name = r.name; mealTypeRaw = r.mealTypeRaw; servings = r.servings
        prepMinutes = r.prepMinutes; ingredients = r.ingredients; instructions = r.instructions
        tags = r.tags; isFavorite = r.isFavorite; isCustom = r.isCustom
    }

    func makeModel() -> Recipe {
        let r = Recipe(name: name, mealType: .dinner, servings: servings, prepMinutes: prepMinutes,
                       ingredients: ingredients, instructions: instructions, tags: tags, isCustom: isCustom)
        r.uuid = uuid; r.mealTypeRaw = mealTypeRaw; r.isFavorite = isFavorite
        return r
    }
}

struct MealPlanRecord: BackupRecord {
    var uuid: UUID
    var day: Date
    var mealTypeRaw: String
    var title: String
    var servings: Double
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var carbsPerServing: Double
    var fatPerServing: Double
    var recipeID: UUID?
    var foodItemID: UUID?
    var batchID: UUID?
    var isLogged: Bool

    init(_ m: MealPlanEntry) {
        uuid = m.uuid; day = m.day; mealTypeRaw = m.mealTypeRaw; title = m.title; servings = m.servings
        caloriesPerServing = m.caloriesPerServing; proteinPerServing = m.proteinPerServing
        carbsPerServing = m.carbsPerServing; fatPerServing = m.fatPerServing
        recipeID = m.recipeID; foodItemID = m.foodItemID; batchID = m.batchID; isLogged = m.isLogged
    }

    func makeModel() -> MealPlanEntry {
        let m = MealPlanEntry(day: day, mealType: .dinner, title: title, servings: servings,
                              caloriesPerServing: caloriesPerServing, proteinPerServing: proteinPerServing,
                              carbsPerServing: carbsPerServing, fatPerServing: fatPerServing,
                              recipeID: recipeID, foodItemID: foodItemID)
        m.uuid = uuid; m.day = day; m.mealTypeRaw = mealTypeRaw; m.batchID = batchID; m.isLogged = isLogged
        return m
    }
}

struct SavedMealRecord: BackupRecord {
    var uuid: UUID
    var name: String
    var mealTypeRaw: String
    var items: [SavedMealItem]
    var createdAt: Date
    var lastUsed: Date?
    var useCount: Int
    var photo: Data?

    init(_ s: SavedMeal) {
        uuid = s.uuid; name = s.name; mealTypeRaw = s.mealTypeRaw; items = s.items
        createdAt = s.createdAt; lastUsed = s.lastUsed; useCount = s.useCount; photo = s.photo
    }

    func makeModel() -> SavedMeal {
        let s = SavedMeal(name: name, mealType: .snack, items: items)
        s.uuid = uuid; s.mealTypeRaw = mealTypeRaw; s.createdAt = createdAt
        s.lastUsed = lastUsed; s.useCount = useCount; s.photo = photo
        return s
    }
}

struct FastRecord: BackupRecord {
    var uuid: UUID
    var start: Date
    var end: Date?
    var targetHours: Double

    init(_ f: FastingSession) { uuid = f.uuid; start = f.start; end = f.end; targetHours = f.targetHours }

    func makeModel() -> FastingSession {
        let f = FastingSession(start: start, targetHours: targetHours)
        f.uuid = uuid; f.end = end
        return f
    }
}

struct ExerciseRecord: BackupRecord {
    var uuid: UUID
    var date: Date
    var activity: String
    var minutes: Double
    var calories: Double
    var sourceID: String?

    init(_ e: ExerciseEntry) {
        uuid = e.uuid; date = e.date; activity = e.activity; minutes = e.minutes
        calories = e.calories; sourceID = e.sourceID
    }

    func makeModel() -> ExerciseEntry {
        let e = ExerciseEntry(date: date, activity: activity, minutes: minutes, calories: calories)
        e.uuid = uuid; e.sourceID = sourceID
        return e
    }
}

struct BatchRecord: BackupRecord {
    var uuid: UUID
    var name: String
    var recipeID: UUID?
    var cookedAt: Date
    var portionsTotal: Int
    var portionsLeft: Int
    var caloriesPerPortion: Double
    var proteinPerPortion: Double
    var carbsPerPortion: Double
    var fatPerPortion: Double

    init(_ b: MealPrepBatch) {
        uuid = b.uuid; name = b.name; recipeID = b.recipeID; cookedAt = b.cookedAt
        portionsTotal = b.portionsTotal; portionsLeft = b.portionsLeft
        caloriesPerPortion = b.caloriesPerPortion; proteinPerPortion = b.proteinPerPortion
        carbsPerPortion = b.carbsPerPortion; fatPerPortion = b.fatPerPortion
    }

    func makeModel() -> MealPrepBatch {
        // A batch is created from a recipe, so build a stand-in and overwrite every field.
        let stub = Recipe(name: name, mealType: .dinner, servings: 1, prepMinutes: 0, ingredients: [], instructions: "")
        let b = MealPrepBatch(recipe: stub, portions: 1, cookedAt: cookedAt)
        b.uuid = uuid; b.name = name; b.recipeID = recipeID; b.portionsTotal = portionsTotal
        b.portionsLeft = portionsLeft; b.caloriesPerPortion = caloriesPerPortion
        b.proteinPerPortion = proteinPerPortion; b.carbsPerPortion = carbsPerPortion
        b.fatPerPortion = fatPerPortion
        return b
    }
}

struct CheckInRecord: BackupRecord {
    var uuid: UUID
    var day: Date
    var mealTypeRaw: String
    var hunger: Int?
    var mood: Int?

    init(_ c: MealCheckIn) {
        uuid = c.uuid; day = c.day; mealTypeRaw = c.mealTypeRaw; hunger = c.hunger; mood = c.mood
    }

    func makeModel() -> MealCheckIn {
        let c = MealCheckIn(day: day, mealType: .snack, hunger: hunger, mood: mood)
        c.uuid = uuid; c.day = day; c.mealTypeRaw = mealTypeRaw
        return c
    }
}

struct DoseRecord: BackupRecord {
    var uuid: UUID
    var date: Date
    var medication: String
    var doseMg: Double
    var siteRaw: String?
    var sideEffects: [String]
    var note: String
    var healthID: String?

    init(_ d: MedicationDose) {
        uuid = d.uuid; date = d.date; medication = d.medication; doseMg = d.doseMg; siteRaw = d.siteRaw
        sideEffects = d.sideEffects; note = d.note; healthID = d.healthID
    }

    func makeModel() -> MedicationDose {
        let d = MedicationDose(date: date, medication: medication, doseMg: doseMg,
                               sideEffects: sideEffects, note: note)
        d.uuid = uuid; d.siteRaw = siteRaw; d.healthID = healthID
        return d
    }
}
