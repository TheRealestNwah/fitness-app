import Foundation
import SwiftData

/// Built-in foods and recipes inserted on first launch so the diary is useful immediately.
enum SeedData {
    static func seedIfNeeded(context: ModelContext) {
        let foodCount = (try? context.fetchCount(FetchDescriptor<FoodItem>())) ?? 0
        if foodCount == 0 {
            for f in foods { context.insert(f) }
        }
        let recipeCount = (try? context.fetchCount(FetchDescriptor<Recipe>())) ?? 0
        if recipeCount == 0 {
            for r in recipes { context.insert(r) }
        }
        try? context.save()
    }

    // name, serving, kcal, protein, carbs, fat, fiber
    private static let foodTable: [(String, String, Double, Double, Double, Double, Double)] = [
        // Proteins
        ("Egg, large", "1 egg (50 g)", 72, 6.3, 0.4, 4.8, 0),
        ("Egg white", "1 white (33 g)", 17, 3.6, 0.2, 0.1, 0),
        ("Chicken breast, grilled", "100 g", 165, 31, 0, 3.6, 0),
        ("Chicken thigh, roasted", "100 g", 209, 26, 0, 10.9, 0),
        ("Turkey breast, sliced", "100 g", 104, 17, 4, 2, 0),
        ("Lean ground beef (93/7), cooked", "100 g", 182, 25, 0, 8.6, 0),
        ("Salmon, baked", "100 g", 206, 22, 0, 12, 0),
        ("Tuna, canned in water", "1 can (120 g)", 132, 29, 0, 1, 0),
        ("Cod, baked", "100 g", 105, 23, 0, 0.9, 0),
        ("Shrimp, cooked", "100 g", 99, 24, 0.2, 0.3, 0),
        ("Tofu, firm", "100 g", 144, 17, 3, 9, 2),
        ("Tempeh", "100 g", 192, 20, 8, 11, 0),
        ("Greek yogurt, plain nonfat", "170 g", 100, 17, 6, 0.7, 0),
        ("Cottage cheese, low fat", "1/2 cup (113 g)", 90, 12, 5, 2.5, 0),
        ("Whey protein powder", "1 scoop (30 g)", 120, 24, 3, 1.5, 0),
        ("Black beans, cooked", "1/2 cup (86 g)", 114, 7.6, 20, 0.5, 7.5),
        ("Chickpeas, cooked", "1/2 cup (82 g)", 135, 7.3, 22, 2.1, 6),
        ("Lentils, cooked", "1/2 cup (99 g)", 115, 9, 20, 0.4, 7.8),
        ("Edamame, shelled", "1/2 cup (78 g)", 95, 9, 7, 4, 4),
        // Dairy
        ("Milk, 2%", "1 cup (244 ml)", 122, 8, 12, 4.8, 0),
        ("Milk, skim", "1 cup (244 ml)", 83, 8.3, 12, 0.2, 0),
        ("Almond milk, unsweetened", "1 cup (240 ml)", 30, 1, 1, 2.5, 0),
        ("Cheddar cheese", "1 oz (28 g)", 114, 6.5, 0.4, 9.4, 0),
        ("Mozzarella, part skim", "1 oz (28 g)", 72, 6.9, 0.8, 4.5, 0),
        ("Feta cheese", "1 oz (28 g)", 75, 4, 1.2, 6, 0),
        ("Butter", "1 tbsp (14 g)", 102, 0.1, 0, 11.5, 0),
        // Grains & starches
        ("Oats, rolled (dry)", "1/2 cup (40 g)", 150, 5, 27, 3, 4),
        ("Brown rice, cooked", "1 cup (195 g)", 216, 5, 45, 1.8, 3.5),
        ("White rice, cooked", "1 cup (158 g)", 205, 4.3, 45, 0.4, 0.6),
        ("Quinoa, cooked", "1 cup (185 g)", 222, 8, 39, 3.6, 5),
        ("Whole wheat bread", "1 slice (43 g)", 110, 5, 20, 1.5, 3),
        ("White bread", "1 slice (30 g)", 79, 2.7, 15, 1, 0.6),
        ("Whole wheat pasta, cooked", "1 cup (140 g)", 174, 7.5, 37, 0.8, 6),
        ("Pasta, cooked", "1 cup (140 g)", 220, 8, 43, 1.3, 2.5),
        ("Sweet potato, baked", "1 medium (150 g)", 135, 3, 31, 0.2, 5),
        ("Potato, baked", "1 medium (173 g)", 161, 4.3, 37, 0.2, 3.8),
        ("Corn tortilla", "1 tortilla (26 g)", 60, 1.5, 12, 0.7, 1.5),
        ("Flour tortilla", "1 tortilla (49 g)", 146, 4, 25, 3.5, 1.5),
        ("Bagel, plain", "1 bagel (105 g)", 289, 11, 56, 1.7, 2.4),
        ("Granola", "1/4 cup (30 g)", 140, 3, 18, 6, 2),
        ("Cereal, bran flakes", "1 cup (30 g)", 100, 3, 24, 0.5, 5),
        // Fruit
        ("Apple", "1 medium (182 g)", 95, 0.5, 25, 0.3, 4.4),
        ("Banana", "1 medium (118 g)", 105, 1.3, 27, 0.4, 3.1),
        ("Orange", "1 medium (131 g)", 62, 1.2, 15, 0.2, 3.1),
        ("Blueberries", "1 cup (148 g)", 84, 1.1, 21, 0.5, 3.6),
        ("Strawberries", "1 cup (152 g)", 49, 1, 12, 0.5, 3),
        ("Grapes", "1 cup (151 g)", 104, 1.1, 27, 0.2, 1.4),
        ("Avocado", "1/2 avocado (68 g)", 114, 1.3, 6, 10.5, 4.6),
        ("Mango", "1 cup (165 g)", 99, 1.4, 25, 0.6, 2.6),
        ("Watermelon", "1 cup (152 g)", 46, 0.9, 11, 0.2, 0.6),
        ("Pear", "1 medium (178 g)", 101, 0.6, 27, 0.2, 5.5),
        ("Raspberries", "1 cup (123 g)", 64, 1.5, 15, 0.8, 8),
        // Vegetables
        ("Broccoli, steamed", "1 cup (156 g)", 55, 3.7, 11, 0.6, 5),
        ("Spinach, raw", "2 cups (60 g)", 14, 1.7, 2.2, 0.2, 1.3),
        ("Mixed salad greens", "2 cups (85 g)", 20, 1.5, 3.5, 0.3, 2),
        ("Carrot", "1 medium (61 g)", 25, 0.6, 6, 0.1, 1.7),
        ("Bell pepper", "1 medium (119 g)", 31, 1, 7, 0.3, 2.5),
        ("Cucumber", "1 cup sliced (104 g)", 16, 0.7, 3.8, 0.1, 0.5),
        ("Tomato", "1 medium (123 g)", 22, 1.1, 4.8, 0.2, 1.5),
        ("Cherry tomatoes", "1 cup (149 g)", 27, 1.3, 5.8, 0.3, 1.8),
        ("Zucchini", "1 medium (196 g)", 33, 2.4, 6, 0.6, 2),
        ("Cauliflower, roasted", "1 cup (124 g)", 60, 2.3, 6, 3.5, 2.5),
        ("Green beans", "1 cup (125 g)", 44, 2.4, 10, 0.4, 4),
        ("Asparagus", "6 spears (90 g)", 20, 2.2, 3.7, 0.2, 1.8),
        ("Onion", "1/2 medium (55 g)", 22, 0.6, 5, 0.1, 0.9),
        ("Mushrooms", "1 cup (70 g)", 15, 2.2, 2.3, 0.2, 0.7),
        ("Kale, raw", "2 cups (40 g)", 20, 1.7, 3.5, 0.4, 1.4),
        // Fats, nuts, seeds
        ("Olive oil", "1 tbsp (14 g)", 119, 0, 0, 13.5, 0),
        ("Almonds", "1 oz (28 g, ~23 nuts)", 164, 6, 6, 14, 3.5),
        ("Walnuts", "1 oz (28 g)", 185, 4.3, 3.9, 18.5, 1.9),
        ("Peanut butter", "1 tbsp (16 g)", 94, 4, 3.5, 8, 1),
        ("Almond butter", "1 tbsp (16 g)", 98, 3.4, 3, 9, 1.6),
        ("Chia seeds", "1 tbsp (12 g)", 58, 2, 5, 3.7, 4),
        ("Flaxseed, ground", "1 tbsp (7 g)", 37, 1.3, 2, 3, 1.9),
        ("Hummus", "2 tbsp (30 g)", 70, 2, 6, 5, 2),
        // Drinks
        ("Coffee, black", "1 cup (240 ml)", 2, 0.3, 0, 0, 0),
        ("Latte, 2% milk", "12 fl oz (355 ml)", 150, 10, 15, 6, 0),
        ("Orange juice", "1 cup (248 ml)", 112, 1.7, 26, 0.5, 0.5),
        ("Cola", "12 fl oz can (355 ml)", 140, 0, 39, 0, 0),
        ("Beer, regular", "12 fl oz (355 ml)", 153, 1.6, 13, 0, 0),
        ("Wine, red", "5 fl oz (148 ml)", 125, 0.1, 3.8, 0, 0),
        ("Protein shake, ready to drink", "1 bottle (325 ml)", 160, 30, 5, 3, 1),
        // Snacks & convenience
        ("Dark chocolate, 70%", "1 oz (28 g)", 170, 2.2, 13, 12, 3),
        ("Rice cakes", "1 cake (9 g)", 35, 0.7, 7.3, 0.3, 0.4),
        ("Protein bar", "1 bar (60 g)", 210, 20, 22, 7, 5),
        ("Popcorn, air-popped", "3 cups (24 g)", 93, 3, 19, 1.1, 3.6),
        ("Tortilla chips", "1 oz (28 g)", 140, 2, 19, 7, 1),
        ("Pizza, cheese", "1 slice (107 g)", 285, 12, 36, 10, 2.5),
        ("Cheeseburger, fast food", "1 burger (150 g)", 400, 20, 36, 19, 1.5),
        ("French fries", "medium (117 g)", 365, 4, 48, 17, 4),
        ("Sushi roll, California", "6 pieces (170 g)", 255, 9, 38, 7, 3),
        ("Chocolate chip cookie", "1 cookie (30 g)", 148, 1.5, 20, 7, 0.6),
        ("Ice cream, vanilla", "1/2 cup (66 g)", 137, 2.3, 16, 7, 0.5),
        ("Honey", "1 tbsp (21 g)", 64, 0.1, 17, 0, 0),
        ("Ketchup", "1 tbsp (17 g)", 17, 0.2, 4.5, 0, 0),
        ("Mayonnaise", "1 tbsp (14 g)", 94, 0.1, 0.1, 10, 0),
        ("Ranch dressing", "2 tbsp (30 g)", 129, 0.4, 1.8, 13.5, 0),
        ("Salsa", "2 tbsp (32 g)", 9, 0.4, 2, 0, 0.5),
        ("Soy sauce", "1 tbsp (16 g)", 9, 1.3, 0.8, 0, 0),
    ]

    static var foods: [FoodItem] {
        foodTable.map { row in
            FoodItem(name: row.0, servingDescription: row.1, calories: row.2,
                     protein: row.3, carbs: row.4, fat: row.5, fiber: row.6)
        }
    }

    private static func ing(_ name: String, _ amount: String, _ kcal: Double, _ p: Double, _ c: Double, _ f: Double) -> Ingredient {
        Ingredient(name: name, amount: amount, calories: kcal, protein: p, carbs: c, fat: f)
    }

    static var recipes: [Recipe] {
        [
            Recipe(name: "Overnight oats with berries", mealType: .breakfast, servings: 1, prepMinutes: 5,
                   ingredients: [
                    ing("Rolled oats", "1/2 cup (40 g)", 150, 5, 27, 3),
                    ing("Greek yogurt, plain nonfat", "1/2 cup (120 g)", 70, 12, 4, 0.5),
                    ing("Milk, skim", "1/2 cup (120 ml)", 42, 4, 6, 0.1),
                    ing("Blueberries", "1/2 cup (74 g)", 42, 0.5, 10, 0.2),
                    ing("Chia seeds", "1 tbsp (12 g)", 58, 2, 5, 3.7),
                    ing("Honey", "1 tsp (7 g)", 21, 0, 6, 0),
                   ],
                   instructions: "Stir oats, yogurt, milk, chia and honey in a jar. Refrigerate overnight. Top with blueberries before eating.",
                   tags: ["High fibre", "Make ahead"]),
            Recipe(name: "Veggie egg scramble on toast", mealType: .breakfast, servings: 1, prepMinutes: 10,
                   ingredients: [
                    ing("Eggs", "2 large", 144, 12.6, 0.8, 9.6),
                    ing("Spinach", "1 cup (30 g)", 7, 0.9, 1.1, 0.1),
                    ing("Cherry tomatoes", "1/2 cup (75 g)", 14, 0.7, 2.9, 0.2),
                    ing("Whole wheat bread", "1 slice (43 g)", 110, 5, 20, 1.5),
                    ing("Olive oil", "1 tsp (5 g)", 40, 0, 0, 4.5),
                   ],
                   instructions: "Heat oil in a nonstick pan. Wilt spinach and tomatoes for a minute, add beaten eggs and scramble gently. Serve on toast.",
                   tags: ["High protein", "Quick"]),
            Recipe(name: "Banana protein smoothie", mealType: .breakfast, servings: 1, prepMinutes: 5,
                   ingredients: [
                    ing("Banana", "1 medium (118 g)", 105, 1.3, 27, 0.4),
                    ing("Whey protein powder", "1 scoop (30 g)", 120, 24, 3, 1.5),
                    ing("Almond milk, unsweetened", "1 cup (240 ml)", 30, 1, 1, 2.5),
                    ing("Peanut butter", "1 tbsp (16 g)", 94, 4, 3.5, 8),
                    ing("Ice", "handful", 0, 0, 0, 0),
                   ],
                   instructions: "Blend everything until smooth. Add more milk to thin.",
                   tags: ["High protein", "Quick"]),
            Recipe(name: "Greek yogurt parfait", mealType: .breakfast, servings: 1, prepMinutes: 3,
                   ingredients: [
                    ing("Greek yogurt, plain nonfat", "170 g", 100, 17, 6, 0.7),
                    ing("Granola", "1/4 cup (30 g)", 140, 3, 18, 6),
                    ing("Strawberries", "1/2 cup (76 g)", 25, 0.5, 6, 0.2),
                   ],
                   instructions: "Layer yogurt, granola and berries in a glass.",
                   tags: ["Quick"]),

            Recipe(name: "Grilled chicken salad", mealType: .lunch, servings: 1, prepMinutes: 15,
                   ingredients: [
                    ing("Chicken breast, grilled", "120 g", 198, 37, 0, 4.3),
                    ing("Mixed salad greens", "2 cups (85 g)", 20, 1.5, 3.5, 0.3),
                    ing("Cherry tomatoes", "1/2 cup (75 g)", 14, 0.7, 2.9, 0.2),
                    ing("Cucumber", "1/2 cup (52 g)", 8, 0.3, 1.9, 0.1),
                    ing("Feta cheese", "1 oz (28 g)", 75, 4, 1.2, 6),
                    ing("Olive oil", "1 tbsp (14 g)", 119, 0, 0, 13.5),
                    ing("Lemon juice", "1 tbsp", 4, 0, 1, 0),
                   ],
                   instructions: "Season and grill chicken 5–6 minutes a side. Slice over greens, tomatoes and cucumber. Crumble feta, dress with oil and lemon.",
                   tags: ["High protein", "Low carb"]),
            Recipe(name: "Turkey and avocado wrap", mealType: .lunch, servings: 1, prepMinutes: 5,
                   ingredients: [
                    ing("Flour tortilla", "1 tortilla (49 g)", 146, 4, 25, 3.5),
                    ing("Turkey breast, sliced", "85 g", 88, 14, 3.4, 1.7),
                    ing("Avocado", "1/4 avocado (34 g)", 57, 0.7, 3, 5.3),
                    ing("Spinach", "1 cup (30 g)", 7, 0.9, 1.1, 0.1),
                    ing("Tomato", "1/2 medium (62 g)", 11, 0.5, 2.4, 0.1),
                    ing("Hummus", "1 tbsp (15 g)", 35, 1, 3, 2.5),
                   ],
                   instructions: "Spread hummus on the tortilla, layer turkey, avocado, spinach and tomato. Roll tightly and halve.",
                   tags: ["Quick", "Packable"]),
            Recipe(name: "Lentil and vegetable soup", mealType: .lunch, servings: 4, prepMinutes: 35,
                   ingredients: [
                    ing("Lentils, dry", "1 cup (190 g)", 670, 48, 115, 2),
                    ing("Carrot", "2 medium (122 g)", 50, 1.2, 12, 0.2),
                    ing("Onion", "1 medium (110 g)", 44, 1.2, 10, 0.2),
                    ing("Celery", "2 stalks (80 g)", 13, 0.6, 2.4, 0.1),
                    ing("Canned tomatoes", "1 can (400 g)", 80, 4, 16, 0.8),
                    ing("Olive oil", "1 tbsp (14 g)", 119, 0, 0, 13.5),
                    ing("Vegetable stock", "4 cups (1 L)", 40, 2, 8, 0),
                   ],
                   instructions: "Sweat onion, carrot and celery in oil. Add lentils, tomatoes and stock. Simmer 25 minutes until lentils are tender. Season well.",
                   tags: ["High fibre", "Batch cook", "Vegan"]),
            Recipe(name: "Tuna and white bean salad", mealType: .lunch, servings: 1, prepMinutes: 8,
                   ingredients: [
                    ing("Tuna, canned in water", "1 can (120 g)", 132, 29, 0, 1),
                    ing("Cannellini beans", "1/2 cup (90 g)", 110, 7, 20, 0.5),
                    ing("Red onion", "2 tbsp (20 g)", 8, 0.2, 2, 0),
                    ing("Olive oil", "2 tsp (9 g)", 80, 0, 0, 9),
                    ing("Lemon juice", "1 tbsp", 4, 0, 1, 0),
                    ing("Mixed salad greens", "2 cups (85 g)", 20, 1.5, 3.5, 0.3),
                   ],
                   instructions: "Flake tuna, toss with beans, onion, oil and lemon. Serve over greens.",
                   tags: ["High protein", "No cook"]),

            Recipe(name: "Salmon with roasted vegetables", mealType: .dinner, servings: 1, prepMinutes: 25,
                   ingredients: [
                    ing("Salmon fillet", "140 g", 288, 31, 0, 17),
                    ing("Broccoli", "1 cup (90 g)", 31, 2.6, 6, 0.4),
                    ing("Sweet potato", "1 small (100 g)", 90, 2, 21, 0.1),
                    ing("Olive oil", "2 tsp (9 g)", 80, 0, 0, 9),
                   ],
                   instructions: "Toss vegetables with oil, roast at 200°C for 15 minutes. Add salmon to the tray and roast 10–12 minutes more.",
                   tags: ["High protein", "One tray"]),
            Recipe(name: "Chicken stir-fry with rice", mealType: .dinner, servings: 2, prepMinutes: 20,
                   ingredients: [
                    ing("Chicken breast", "300 g", 495, 93, 0, 10.8),
                    ing("Bell pepper", "2 medium (238 g)", 62, 2, 14, 0.6),
                    ing("Broccoli", "2 cups (180 g)", 62, 5.2, 12, 0.8),
                    ing("Soy sauce", "2 tbsp (32 g)", 18, 2.6, 1.6, 0),
                    ing("Garlic and ginger", "1 tbsp", 10, 0.3, 2, 0),
                    ing("Sesame oil", "2 tsp (9 g)", 80, 0, 0, 9),
                    ing("Brown rice, cooked", "2 cups (390 g)", 432, 10, 90, 3.6),
                   ],
                   instructions: "Stir-fry sliced chicken in oil until golden. Add vegetables, garlic and ginger, cook 4 minutes. Splash in soy sauce. Serve over rice.",
                   tags: ["High protein", "Batch cook"]),
            Recipe(name: "Turkey chili", mealType: .dinner, servings: 4, prepMinutes: 40,
                   ingredients: [
                    ing("Lean ground turkey", "500 g", 745, 100, 0, 37),
                    ing("Kidney beans, canned", "1 can (400 g)", 300, 20, 52, 1.6),
                    ing("Canned tomatoes", "1 can (400 g)", 80, 4, 16, 0.8),
                    ing("Onion", "1 medium (110 g)", 44, 1.2, 10, 0.2),
                    ing("Bell pepper", "1 medium (119 g)", 31, 1, 7, 0.3),
                    ing("Olive oil", "1 tbsp (14 g)", 119, 0, 0, 13.5),
                    ing("Chili spices", "2 tbsp", 30, 1, 6, 1),
                   ],
                   instructions: "Brown turkey with onion and pepper in oil. Add spices, tomatoes and beans. Simmer 25 minutes. Freezes well.",
                   tags: ["High protein", "Batch cook"]),
            Recipe(name: "Shrimp and zucchini noodles", mealType: .dinner, servings: 1, prepMinutes: 15,
                   ingredients: [
                    ing("Shrimp, cooked", "150 g", 149, 36, 0.3, 0.5),
                    ing("Zucchini, spiralised", "2 medium (392 g)", 66, 4.8, 12, 1.2),
                    ing("Cherry tomatoes", "1 cup (149 g)", 27, 1.3, 5.8, 0.3),
                    ing("Garlic", "2 cloves", 9, 0.4, 2, 0),
                    ing("Olive oil", "1 tbsp (14 g)", 119, 0, 0, 13.5),
                    ing("Parmesan", "1 tbsp (5 g)", 21, 2, 0, 1.4),
                   ],
                   instructions: "Sauté garlic in oil, add tomatoes until they burst. Toss in shrimp and zucchini noodles for 2 minutes. Finish with parmesan.",
                   tags: ["Low carb", "Quick"]),
            Recipe(name: "Tofu veggie curry with rice", mealType: .dinner, servings: 2, prepMinutes: 25,
                   ingredients: [
                    ing("Tofu, firm", "300 g", 432, 51, 9, 27),
                    ing("Light coconut milk", "1 cup (240 ml)", 150, 1, 4, 14),
                    ing("Curry paste", "2 tbsp", 40, 1, 6, 1),
                    ing("Cauliflower", "2 cups (200 g)", 50, 4, 10, 0.6),
                    ing("Green beans", "1 cup (125 g)", 44, 2.4, 10, 0.4),
                    ing("White rice, cooked", "1.5 cups (237 g)", 308, 6.4, 67, 0.6),
                   ],
                   instructions: "Fry curry paste, add coconut milk and vegetables, simmer 8 minutes. Add cubed tofu and warm through. Serve with rice.",
                   tags: ["Vegan", "Batch cook"]),

            Recipe(name: "Apple with peanut butter", mealType: .snack, servings: 1, prepMinutes: 2,
                   ingredients: [
                    ing("Apple", "1 medium (182 g)", 95, 0.5, 25, 0.3),
                    ing("Peanut butter", "1 tbsp (16 g)", 94, 4, 3.5, 8),
                   ],
                   instructions: "Slice the apple and dip.",
                   tags: ["Quick"]),
            Recipe(name: "Cottage cheese and berries", mealType: .snack, servings: 1, prepMinutes: 2,
                   ingredients: [
                    ing("Cottage cheese, low fat", "1/2 cup (113 g)", 90, 12, 5, 2.5),
                    ing("Raspberries", "1/2 cup (62 g)", 32, 0.7, 7.5, 0.4),
                   ],
                   instructions: "Combine and eat.",
                   tags: ["High protein", "Quick"]),
            Recipe(name: "Veggies and hummus", mealType: .snack, servings: 1, prepMinutes: 3,
                   ingredients: [
                    ing("Carrot", "1 medium (61 g)", 25, 0.6, 6, 0.1),
                    ing("Cucumber", "1/2 cup (52 g)", 8, 0.3, 1.9, 0.1),
                    ing("Hummus", "3 tbsp (45 g)", 105, 3, 9, 7.5),
                   ],
                   instructions: "Cut vegetables into sticks and dip.",
                   tags: ["Vegan", "Quick"]),
        ]
    }

    static let tips: [String] = [
        String(localized: "Weigh yourself at the same time each morning; the trend line matters more than any single day."),
        String(localized: "Protein keeps you full longer. Aim to include a palm-sized portion in every meal."),
        String(localized: "Drink a glass of water before meals. Thirst is often mistaken for hunger."),
        String(localized: "Plan tomorrow's meals tonight. Decisions made hungry are rarely good ones."),
        String(localized: "A 500 kcal daily deficit adds up to roughly half a kilo of fat a week."),
        String(localized: "Fibre-rich vegetables add volume to meals for very few calories."),
        String(localized: "Sleep under 7 hours raises hunger hormones. Rest is part of the plan."),
        String(localized: "Log the slip-up meal too. Data, not guilt, is what moves the needle."),
        String(localized: "Walking after meals helps blunt blood sugar spikes and adds up over a week."),
        String(localized: "Weight fluctuates 1–2 kg day to day from water alone. Judge progress by the weekly average."),
        String(localized: "Keep easy high-protein snacks around so hunger never catches you unprepared."),
        String(localized: "Cook once, eat twice. Batch cooking removes the biggest weeknight temptation."),
    ]
}
