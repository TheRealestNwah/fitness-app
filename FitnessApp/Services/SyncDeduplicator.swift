import Foundation
import CryptoKit
import SwiftData

/// With iCloud sync, two devices can each create the same built-in foods, recipes and a profile
/// before they first sync. This folds those copies back into one, pointing logged entries,
/// plans and saved meals at the copy that's kept. The person's own foods and recipes are never
/// merged, since two with the same name can be deliberate.
enum SyncDeduplicator {
    /// A uuid derived from a seed record's identity, so every device seeds the same ids.
    static func stableID(_ key: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    static func seedKey(food: FoodItem) -> String {
        "food|\(food.name)|\(food.brand)|\(food.servingDescription)".lowercased()
    }

    static func seedKey(recipe: Recipe) -> String {
        "recipe|\(recipe.name)".lowercased()
    }

    /// Returns whether anything was merged.
    @discardableResult
    static func run(context: ModelContext) -> Bool {
        let profiles = mergeProfiles(context)
        let foods = mergeFoods(context)
        let recipes = mergeRecipes(context)
        guard profiles || foods || recipes else { return false }
        try? context.save()
        return true
    }

    /// Keeps the profile whose journey started first; later ones came from setting up another device.
    private static func mergeProfiles(_ context: ModelContext) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.startDate)]))) ?? []
        guard all.count > 1 else { return false }
        for extra in all.dropFirst() { context.delete(extra) }
        return true
    }

    private static func mergeFoods(_ context: ModelContext) -> Bool {
        let builtIn = (try? context.fetch(FetchDescriptor<FoodItem>(predicate: #Predicate { !$0.isCustom }))) ?? []
        var replaced: [UUID: UUID] = [:]
        for group in Dictionary(grouping: builtIn, by: seedKey(food:)).values where group.count > 1 {
            let keeper = group.min(by: keeps(_:over:))!
            for food in group where food !== keeper {
                keeper.isFavorite = keeper.isFavorite || food.isFavorite
                keeper.useCount = max(keeper.useCount, food.useCount)
                keeper.lastUsed = [keeper.lastUsed, food.lastUsed].compactMap { $0 }.max()
                if keeper.barcode == nil { keeper.barcode = food.barcode }
                replaced[food.uuid] = keeper.uuid
                context.delete(food)
            }
        }
        guard !replaced.isEmpty else { return false }
        for entry in (try? context.fetch(FetchDescriptor<FoodLogEntry>())) ?? [] {
            if let id = entry.foodItemID, let new = replaced[id] { entry.foodItemID = new }
        }
        for entry in (try? context.fetch(FetchDescriptor<MealPlanEntry>())) ?? [] {
            if let id = entry.foodItemID, let new = replaced[id] { entry.foodItemID = new }
        }
        for meal in (try? context.fetch(FetchDescriptor<SavedMeal>())) ?? [] {
            let items = meal.items.map { item -> SavedMealItem in
                var item = item
                if let id = item.foodItemID, let new = replaced[id] { item.foodItemID = new }
                return item
            }
            if items != meal.items { meal.items = items }
        }
        return true
    }

    private static func mergeRecipes(_ context: ModelContext) -> Bool {
        let builtIn = (try? context.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { !$0.isCustom }))) ?? []
        var replaced: [UUID: UUID] = [:]
        for group in Dictionary(grouping: builtIn, by: seedKey(recipe:)).values where group.count > 1 {
            let keeper = group.contains(where: \.isFavorite)
                ? group.first(where: \.isFavorite)!
                : group.min(by: { $0.uuid.uuidString < $1.uuid.uuidString })!
            for recipe in group where recipe !== keeper {
                replaced[recipe.uuid] = keeper.uuid
                context.delete(recipe)
            }
        }
        guard !replaced.isEmpty else { return false }
        for entry in (try? context.fetch(FetchDescriptor<MealPlanEntry>())) ?? [] {
            if let id = entry.recipeID, let new = replaced[id] { entry.recipeID = new }
        }
        for batch in (try? context.fetch(FetchDescriptor<MealPrepBatch>())) ?? [] {
            if let id = batch.recipeID, let new = replaced[id] { batch.recipeID = new }
        }
        return true
    }

    /// Which copy of a food to keep: a favourite, then the most used, then the most recently used.
    /// Ties go to the smallest uuid so every device makes the same choice.
    static func keeps(_ a: FoodItem, over b: FoodItem) -> Bool {
        if a.isFavorite != b.isFavorite { return a.isFavorite }
        if a.useCount != b.useCount { return a.useCount > b.useCount }
        let aUsed = a.lastUsed ?? .distantPast, bUsed = b.lastUsed ?? .distantPast
        if aUsed != bUsed { return aUsed > bUsed }
        return a.uuid.uuidString < b.uuid.uuidString
    }
}
