import Foundation
import SwiftData

/// Launch-argument hooks used by UI tests and for trying the app with realistic data.
///
/// - `-resetData`: wipe every record so the app starts at onboarding.
/// - `-demoData`: wipe, then load a sample profile with six weeks of history.
enum DemoData {
    static var shouldReset: Bool { CommandLine.arguments.contains("-resetData") }
    static var shouldLoadDemo: Bool { CommandLine.arguments.contains("-demoData") }

    static func applyLaunchArguments(context: ModelContext) {
        guard shouldReset || shouldLoadDemo else { return }
        wipe(context: context)
        if shouldLoadDemo {
            SeedData.seedIfNeeded(context: context)
            load(context: context)
        }
        try? context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        guard let items = try? context.fetch(FetchDescriptor<T>()) else { return }
        for item in items { context.delete(item) }
    }

    static func wipe(context: ModelContext) {
        deleteAll(WeightEntry.self, in: context)
        deleteAll(FoodLogEntry.self, in: context)
        deleteAll(VitalsEntry.self, in: context)
        deleteAll(WaterEntry.self, in: context)
        deleteAll(MealPlanEntry.self, in: context)
        deleteAll(SavedMeal.self, in: context)
        deleteAll(FoodItem.self, in: context)
        deleteAll(Recipe.self, in: context)
        deleteAll(UserProfile.self, in: context)
        try? context.save()
    }

    static func load(context: ModelContext) {
        let cal = Calendar.current
        let today = Date.now.startOfDay
        func day(_ offset: Int, hour: Int = 8) -> Date {
            cal.date(byAdding: .hour, value: hour, to: today.adding(days: offset)) ?? today
        }

        let profile = UserProfile(name: "Sam",
                                  sex: .female,
                                  birthDate: cal.date(byAdding: .year, value: -34, to: today) ?? today,
                                  heightCm: 168,
                                  startWeightKg: 84.0,
                                  goalWeightKg: 70.0,
                                  activityLevel: .light,
                                  weeklyLossKg: 0.5,
                                  unitSystem: .metric)
        profile.startDate = day(-42)
        profile.waterGoalMl = 2500
        context.insert(profile)

        // Six weeks of weigh-ins trending down with day-to-day noise.
        var weight = 84.0
        for offset in stride(from: -42, through: 0, by: 1) {
            if offset % 7 == 3 { continue } // an occasional missed day
            let noise = [0.4, -0.3, 0.2, -0.5, 0.1, -0.2, 0.3][abs(offset) % 7]
            let entry = WeightEntry(date: day(offset, hour: 7), weightKg: (weight + noise * 0.6).rounded(toPlaces: 1))
            context.insert(entry)
            weight -= 0.5 / 7
        }

        // Today's diary.
        let meals: [(MealType, String, Double, Double, Double, Double, Double, String)] = [
            (.breakfast, "Overnight oats with berries", 1, 383, 23.5, 58, 7.5, "serving"),
            (.breakfast, "Coffee, black", 1, 2, 0.3, 0, 0, "1 cup (240 ml)"),
            (.lunch, "Grilled chicken salad", 1, 438, 43.5, 9.5, 24.4, "serving"),
            (.lunch, "Apple", 1, 95, 0.5, 25, 0.3, "1 medium (182 g)"),
            (.snack, "Greek yogurt, plain nonfat", 1, 100, 17, 6, 0.7, "170 g"),
            (.snack, "Almonds", 1, 164, 6, 6, 14, "1 oz (28 g, ~23 nuts)"),
        ]
        for (meal, name, servings, kcal, p, c, f, serving) in meals {
            let hour: Int
            switch meal {
            case .breakfast: hour = 8
            case .lunch: hour = 13
            case .dinner: hour = 19
            case .snack: hour = 16
            }
            context.insert(FoodLogEntry(date: day(0, hour: hour), mealType: meal, foodName: name, servings: servings,
                                        servingDescription: serving, calories: kcal, protein: p, carbs: c, fat: f))
        }
        // Recent days so the streak counter has something to show.
        for offset in -6...(-1) {
            context.insert(FoodLogEntry(date: day(offset, hour: 13), mealType: .lunch, foodName: "Turkey and avocado wrap",
                                        servings: 1, servingDescription: "serving", calories: 344, protein: 21, carbs: 38, fat: 13))
        }

        for i in 0..<4 {
            context.insert(WaterEntry(date: day(0, hour: 9 + i * 2), amountMl: 250))
        }

        // Weekly vitals.
        let bp: [(Int, Int, Int, Double, Double, Double)] = [
            (134, 86, 74, 34.0, 92.0, 6.4),
            (131, 84, 72, 33.4, 90.5, 6.8),
            (128, 82, 70, 32.9, 89.0, 7.1),
            (126, 81, 69, 32.5, 88.0, 7.3),
            (124, 80, 67, 32.0, 86.5, 7.5),
            (122, 79, 66, 31.6, 85.5, 7.4),
            (121, 78, 65, 31.2, 84.5, 7.6),
        ]
        for (i, v) in bp.enumerated() {
            let entry = VitalsEntry(date: day(-42 + i * 7, hour: 7))
            entry.systolic = v.0
            entry.diastolic = v.1
            entry.restingHeartRate = v.2
            entry.bodyFatPercent = v.3
            entry.waistCm = v.4
            entry.sleepHours = v.5
            context.insert(entry)
        }

        // Meal plan for today and tomorrow, linked to seeded recipes.
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        func recipe(_ name: String) -> Recipe? { recipes.first { $0.name == name } }
        let plan: [(Int, MealType, String, Bool)] = [
            (0, .breakfast, "Overnight oats with berries", true),
            (0, .lunch, "Grilled chicken salad", true),
            (0, .dinner, "Salmon with roasted vegetables", false),
            (0, .snack, "Cottage cheese and berries", false),
            (1, .breakfast, "Veggie egg scramble on toast", false),
            (1, .lunch, "Lentil and vegetable soup", false),
            (1, .dinner, "Chicken stir-fry with rice", false),
            (1, .snack, "Apple with peanut butter", false),
        ]
        for (offset, meal, name, logged) in plan {
            guard let r = recipe(name) else { continue }
            let entry = MealPlanEntry(day: today.adding(days: offset), mealType: meal, title: r.name,
                                      caloriesPerServing: r.caloriesPerServing, proteinPerServing: r.proteinPerServing,
                                      carbsPerServing: r.carbsPerServing, fatPerServing: r.fatPerServing, recipeID: r.uuid)
            entry.isLogged = logged
            context.insert(entry)
        }

        // A few recently used foods for the search sheet.
        let foods = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
        for (i, name) in ["Greek yogurt, plain nonfat", "Chicken breast, grilled", "Banana", "Almonds", "Egg, large"].enumerated() {
            if let f = foods.first(where: { $0.name == name }) {
                f.lastUsed = day(0, hour: 12 - i)
                f.useCount = 5 - i
            }
        }
        // Two favourite meals so the one-tap section has content.
        context.insert(SavedMeal(name: "Weekday breakfast", mealType: .breakfast, items: [
            SavedMealItem(foodName: "Overnight oats with berries", servings: 1, servingDescription: "serving",
                          calories: 383, protein: 23.5, carbs: 58, fat: 7.5),
            SavedMealItem(foodName: "Coffee, black", servings: 1, servingDescription: "1 cup (240 ml)",
                          calories: 2, protein: 0.3, carbs: 0, fat: 0),
        ]))
        context.insert(SavedMeal(name: "Desk lunch", mealType: .lunch, items: [
            SavedMealItem(foodName: "Turkey and avocado wrap", servings: 1, servingDescription: "serving",
                          calories: 344, protein: 21, carbs: 38, fat: 13),
            SavedMealItem(foodName: "Apple", servings: 1, servingDescription: "1 medium (182 g)",
                          calories: 95, protein: 0.5, carbs: 25, fat: 0.3),
        ]))

        if let f = foods.first(where: { $0.name == "Oats, rolled (dry)" }) { f.isFavorite = true }
        if let f = foods.first(where: { $0.name == "Salmon, baked" }) { f.isFavorite = true }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
