import SwiftData
import SwiftUI

/// Today card: a few favourites, saved meals and recipes that fit what's left, one tap to log.
struct SuggestionsCard: View {
    var remaining: MealSuggester.Macros
    var target: MealSuggester.Macros

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<FoodItem> { $0.isFavorite || $0.useCount > 0 }, sort: \FoodItem.useCount, order: .reverse)
    private var foods: [FoodItem]
    @Query(sort: \SavedMeal.useCount, order: .reverse) private var meals: [SavedMeal]
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @State private var logged: String?

    private var candidates: [MealSuggester.Candidate] {
        var list: [MealSuggester.Candidate] = []
        for food in foods.prefix(60) {
            let servings = food.lastServings ?? 1
            list.append(.init(kind: .food(food.uuid), name: food.displayName,
                              detail: servings == 1 ? food.servingDescription : "\(servings.cleanString) × \(food.servingDescription)",
                              macros: .init(kcal: food.calories * servings, protein: food.protein * servings,
                                            carbs: food.carbs * servings, fat: food.fat * servings)))
        }
        for meal in meals.prefix(30) {
            list.append(.init(kind: .meal(meal.uuid), name: meal.name, detail: "Saved meal",
                              macros: .init(kcal: meal.totalCalories, protein: meal.totalProtein,
                                            carbs: meal.totalCarbs, fat: meal.totalFat)))
        }
        for recipe in recipes {
            list.append(.init(kind: .recipe(recipe.uuid), name: recipe.name, detail: "1 serving",
                              macros: .init(kcal: recipe.caloriesPerServing, protein: recipe.proteinPerServing,
                                            carbs: recipe.carbsPerServing, fat: recipe.fatPerServing)))
        }
        return list
    }

    var body: some View {
        let picks = MealSuggester.suggestions(remaining: remaining, target: target, candidates: candidates)
        if !picks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Fits what's left", systemImage: "sparkles")
                    .font(.headline)
                ForEach(picks, id: \.name) { pick in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pick.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text("\(pick.detail) · \(Energy.string(pick.macros.kcal)) · \(Int(pick.macros.protein.rounded())) g protein")
                                .font(.footnote)
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            log(pick)
                        } label: {
                            Image(systemName: logged == pick.name ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Log \(pick.name)")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .sensoryFeedback(.success, trigger: logged)
        }
    }

    private func log(_ pick: MealSuggester.Candidate) {
        let meal = MealType.current()
        switch pick.kind {
        case .food(let id):
            guard let food = foods.first(where: { $0.uuid == id }) else { return }
            let s = food.lastServings ?? 1
            context.insertDiaryEntry(FoodLogEntry(date: meal.logDate(on: .now), mealType: meal, foodName: food.displayName,
                                                  servings: s, servingDescription: food.servingDescription,
                                                  calories: food.calories * s, protein: food.protein * s,
                                                  carbs: food.carbs * s, fat: food.fat * s, foodItemID: food.uuid,
                                                  fiber: food.fiber * s, sugar: food.sugar * s, sodium: food.sodium * s)
                .withExtras(from: food, servings: s))
            food.lastUsed = .now
            food.useCount += 1
        case .meal(let id):
            meals.first { $0.uuid == id }?.log(on: .now, as: meal, context: context)
        case .recipe(let id):
            guard let recipe = recipes.first(where: { $0.uuid == id }) else { return }
            context.insertDiaryEntry(FoodLogEntry(date: meal.logDate(on: .now), mealType: meal, foodName: recipe.name,
                                                  servings: 1, servingDescription: "serving",
                                                  calories: recipe.caloriesPerServing, protein: recipe.proteinPerServing,
                                                  carbs: recipe.carbsPerServing, fat: recipe.fatPerServing))
        }
        try? context.save()
        logged = pick.name
    }
}
