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
        /// A diary line being moved to another meal.
        case entry
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

    init(entry: FoodLogEntry) {
        kind = .entry
        id = entry.uuid
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
        case .entry:
            return false
        }
        context.saveReportingFailure()
        return true
    }

    /// Logs one serving (a food's last amount) to a diary meal, or moves a dropped diary entry
    /// there. False when it no longer exists.
    @MainActor
    func log(on day: Date, as meal: MealType, context: ModelContext, undo center: UndoCenter? = nil) -> Bool {
        let id = id
        let diary = Diary(context, undo: center)
        switch kind {
        case .entry:
            guard let existing = try? context.fetch(FetchDescriptor<FoodLogEntry>(predicate: #Predicate { $0.uuid == id })).first
            else { return false }
            diary.move([existing], to: meal, on: day)
        case .recipe:
            guard let recipe = try? context.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.uuid == id })).first
            else { return false }
            diary.log(recipe, as: meal, on: day)
        case .food:
            guard let food = try? context.fetch(FetchDescriptor<FoodItem>(predicate: #Predicate { $0.uuid == id })).first
            else { return false }
            diary.log(food, as: meal, on: day)
        }
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
    var perform: (PlatformImage) -> Void
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .onDrop(of: [.image], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) })
                else { return false }
                _ = provider.loadDataRepresentation(for: .image) { data, _ in
                    guard let data, let image = PlatformImage(data: data) else { return }
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
    func imageDropDestination(perform: @escaping (PlatformImage) -> Void) -> some View {
        modifier(ImageDrop(perform: perform))
    }

    /// A card that does something when tapped: highlighted under the pointer on iPad.
    func tappableCard() -> some View {
        card()
            .contentShape(.interaction, RoundedRectangle(cornerRadius: 16, style: .continuous))
            .strideHoverEffect()
    }
}
