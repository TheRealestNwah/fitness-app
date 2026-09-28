import CoreSpotlight
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Puts saved foods, favourite meals and recipes into system search. The whole set is rebuilt
/// shortly after each save, so edits and deletions show up without tracking them one by one.
@MainActor
enum SpotlightIndex {
    /// What a Spotlight result opens.
    enum Target: Equatable {
        case food(UUID)
        case recipe(UUID)
        case meal(UUID)

        init?(identifier: String) {
            let parts = identifier.split(separator: ".", maxSplits: 1).map(String.init)
            guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return nil }
            switch parts[0] {
            case Domain.food.rawValue: self = .food(id)
            case Domain.recipe.rawValue: self = .recipe(id)
            case Domain.meal.rawValue: self = .meal(id)
            default: return nil
            }
        }
    }

    enum Domain: String, CaseIterable {
        case food, recipe, meal
    }

    struct Entry: Equatable {
        var domain: Domain
        var id: UUID
        var title: String
        var detail: String
        var keywords: [String]

        var identifier: String { "\(domain.rawValue).\(id.uuidString)" }
    }

    /// Foods worth finding (your own, favourites and anything logged before), every recipe and every favourite meal.
    static func entries(foods: [FoodItem], recipes: [Recipe], meals: [SavedMeal]) -> [Entry] {
        let savedFoods = foods.filter { $0.isCustom || $0.isFavorite || $0.lastUsed != nil }
        return savedFoods.map {
            Entry(domain: .food, id: $0.uuid, title: $0.displayName,
                  detail: "\($0.servingDescription), \(Energy.string($0.calories))",
                  keywords: [$0.brand].filter { !$0.isEmpty })
        } + recipes.map {
            Entry(domain: .recipe, id: $0.uuid, title: $0.name,
                  detail: String(localized: "Recipe, \(Energy.string($0.caloriesPerServing)) per serving"),
                  keywords: $0.tags + $0.ingredients.map(\.name))
        } + meals.map {
            Entry(domain: .meal, id: $0.uuid, title: $0.name,
                  detail: "\($0.summary), \(Energy.string($0.totalCalories))",
                  keywords: $0.items.map(\.foodName))
        }
    }

    static func entries(in context: ModelContext) -> [Entry] {
        entries(foods: (try? context.fetch(FetchDescriptor<FoodItem>())) ?? [],
                recipes: (try? context.fetch(FetchDescriptor<Recipe>())) ?? [],
                meals: (try? context.fetch(FetchDescriptor<SavedMeal>())) ?? [])
    }

    private static var pending: Task<Void, Never>?

    /// Rebuilds the index a moment after the last call, so a burst of saves costs one rebuild.
    static func scheduleReindex(context: ModelContext) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            let items = entries(in: context).map(searchableItem)
            let index = CSSearchableIndex.default()
            try? await index.deleteSearchableItems(withDomainIdentifiers: Domain.allCases.map(\.rawValue))
            try? await index.indexSearchableItems(items)
        }
    }

    /// Clears everything, for data reset.
    static func removeAll() {
        pending?.cancel()
        CSSearchableIndex.default().deleteAllSearchableItems()
    }

    private static func searchableItem(_ entry: Entry) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = entry.title
        attributes.contentDescription = entry.detail
        attributes.keywords = entry.keywords
        return CSSearchableItem(uniqueIdentifier: entry.identifier, domainIdentifier: entry.domain.rawValue,
                                attributeSet: attributes)
    }
}

/// Keeps the index current and opens whatever was tapped in Spotlight: a food ready to log,
/// a recipe, or food search with the favourite meals at the top.
struct SpotlightSupport: ViewModifier {
    @Environment(\.modelContext) private var context
    @State private var food: FoodItem?
    @State private var recipe: Recipe?
    @State private var showMeals = false

    func body(content: Content) -> some View {
        content
            .onAppear { SpotlightIndex.scheduleReindex(context: context) }
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                Task { @MainActor in SpotlightIndex.scheduleReindex(context: context) }
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                      let target = SpotlightIndex.Target(identifier: identifier) else { return }
                open(target)
            }
            .sheet(item: $food) { food in
                LogFoodSheet(food: food, date: Date.now.startOfDay, mealType: MealType.current())
            }
            .sheet(item: $recipe) { recipe in
                SpotlightRecipeSheet(recipe: recipe)
            }
            .sheet(isPresented: $showMeals) {
                FoodSearchView(date: Date.now.startOfDay, mealType: MealType.current())
            }
    }

    private func open(_ target: SpotlightIndex.Target) {
        switch target {
        case .food(let id):
            food = try? context.fetch(FetchDescriptor<FoodItem>(predicate: #Predicate { $0.uuid == id })).first
        case .recipe(let id):
            recipe = try? context.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.uuid == id })).first
        case .meal:
            showMeals = true
        }
    }
}

private struct SpotlightRecipeSheet: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RecipeDetailView(recipe: recipe)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                }
        }
    }
}

extension View {
    func spotlightSupport() -> some View { modifier(SpotlightSupport()) }
}
