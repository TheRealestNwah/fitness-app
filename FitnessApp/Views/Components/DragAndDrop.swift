import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// A saved food or recipe dragged within Stride (declared in Info.plist).
    static let strideFoodReference = UTType(exportedAs: "com.stride.FitnessApp.food-reference")
}

/// A food or recipe being dragged onto a meal-plan day or a diary meal, e.g. between two iPad windows.
struct FoodReference: Codable, Hashable, Transferable {
    enum Kind: String, Codable {
        case food, recipe
    }

    var kind: Kind
    var id: UUID

    init(food: FoodItem) {
        kind = .food
        id = food.uuid
    }

    init(recipe: Recipe) {
        kind = .recipe
        id = recipe.uuid
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .strideFoodReference)
    }

    /// Adds the food or recipe to a meal-plan slot. False when it no longer exists.
    @MainActor
    func plan(on day: Date, as meal: MealType?, context: ModelContext) -> Bool {
        let id = id
        switch kind {
        case .recipe:
            guard let recipe = try? context.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.uuid == id })).first
            else { return false }
            context.insert(MealPlanEntry(recipe: recipe, day: day, mealType: meal ?? recipe.mealType))
        case .food:
            guard let food = try? context.fetch(FetchDescriptor<FoodItem>(predicate: #Predicate { $0.uuid == id })).first
            else { return false }
            context.insert(MealPlanEntry(food: food, day: day, mealType: meal ?? MealType.current()))
        }
        try? context.save()
        return true
    }

    /// Logs one serving (a food's last amount) to a diary meal. False when it no longer exists.
    @MainActor
    func log(on day: Date, as meal: MealType, context: ModelContext) -> Bool {
        let id = id
        let entry: FoodLogEntry
        switch kind {
        case .recipe:
            guard let recipe = try? context.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.uuid == id })).first
            else { return false }
            entry = FoodLogEntry(date: meal.logDate(on: day), mealType: meal, foodName: recipe.name,
                                 servings: 1, servingDescription: "serving",
                                 calories: recipe.caloriesPerServing, protein: recipe.proteinPerServing,
                                 carbs: recipe.carbsPerServing, fat: recipe.fatPerServing)
        case .food:
            guard let food = try? context.fetch(FetchDescriptor<FoodItem>(predicate: #Predicate { $0.uuid == id })).first
            else { return false }
            let servings = food.lastServings ?? 1
            entry = FoodLogEntry(date: meal.logDate(on: day), mealType: meal, foodName: food.displayName,
                                 servings: servings, servingDescription: food.servingDescription,
                                 calories: food.calories * servings, protein: food.protein * servings,
                                 carbs: food.carbs * servings, fat: food.fat * servings, foodItemID: food.uuid,
                                 fiber: food.fiber * servings, sugar: food.sugar * servings,
                                 sodium: food.sodium * servings)
                .withExtras(from: food, servings: servings)
            food.lastUsed = .now
            food.useCount += 1
        }
        context.insertDiaryEntry(entry)
        try? context.save()
        return true
    }
}

/// Highlights a drop target while something is dragged over it.
private struct DropHighlight: ViewModifier {
    var isTargeted: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct FoodDrop: ViewModifier {
    var perform: ([FoodReference]) -> Bool
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .dropDestination(for: FoodReference.self) { references, _ in
                perform(references)
            } isTargeted: { isTargeted = $0 }
            .modifier(DropHighlight(isTargeted: isTargeted))
    }
}

private struct ImageDrop: ViewModifier {
    var perform: (UIImage) -> Void
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .onDrop(of: [.image], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) })
                else { return false }
                _ = provider.loadDataRepresentation(for: .image) { data, _ in
                    guard let data, let image = UIImage(data: data) else { return }
                    DispatchQueue.main.async { perform(image) }
                }
                return true
            }
            .modifier(DropHighlight(isTargeted: isTargeted))
    }
}

extension View {
    /// Accepts foods and recipes dragged from search or the recipe library.
    func foodDropDestination(perform: @escaping ([FoodReference]) -> Bool) -> some View {
        modifier(FoodDrop(perform: perform))
    }

    /// Accepts an image dragged in from Photos, Files or another app.
    func imageDropDestination(perform: @escaping (UIImage) -> Void) -> some View {
        modifier(ImageDrop(perform: perform))
    }

    /// A card that does something when tapped: highlighted under the pointer on iPad.
    func tappableCard() -> some View {
        card()
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 16, style: .continuous))
            .hoverEffect(.highlight)
    }
}
