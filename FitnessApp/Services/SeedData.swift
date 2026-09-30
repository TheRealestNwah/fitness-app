import Foundation
import SwiftData

/// Built-in foods and recipes inserted on first launch so the diary is useful immediately.
enum SeedData {
    /// Bump when `restaurantTable` gains items, so existing installs pick them up once.
    static let restaurantFoodsVersion = 1
    static let restaurantFoodsVersionKey = "restaurantFoodsVersion"

    static func seedIfNeeded(context: ModelContext, defaults: UserDefaults = .standard) {
        let foodCount = (try? context.fetchCount(FetchDescriptor<FoodItem>())) ?? 0
        if foodCount == 0 {
            for f in foods + restaurantFoods { context.insert(f) }
        } else if defaults.integer(forKey: restaurantFoodsVersionKey) < restaurantFoodsVersion {
            // Existing install: add the chain items it doesn't have yet. Done once per version,
            // so items the user deletes don't come back on the next launch.
            let existing = Set(((try? context.fetch(FetchDescriptor<FoodItem>())) ?? []).map { "\($0.name)|\($0.brand)" })
            for f in restaurantFoods where !existing.contains("\(f.name)|\(f.brand)") { context.insert(f) }
        }
        defaults.set(restaurantFoodsVersion, forKey: restaurantFoodsVersionKey)
        let recipeCount = (try? context.fetchCount(FetchDescriptor<Recipe>())) ?? 0
        if recipeCount == 0 {
            for r in recipes { context.insert(r) }
        }
        try? context.save()
    }

    // name, serving, kcal, protein, carbs, fat, fiber
    private static let foodTable: [(String, String, Double, Double, Double, Double, Double)] = [
        // Proteins
        (String(localized: "Egg, large"), String(localized: "1 egg (50 g)"), 72, 6.3, 0.4, 4.8, 0),
        (String(localized: "Egg white"), String(localized: "1 white (33 g)"), 17, 3.6, 0.2, 0.1, 0),
        (String(localized: "Chicken breast, grilled"), String(localized: "100 g"), 165, 31, 0, 3.6, 0),
        (String(localized: "Chicken thigh, roasted"), String(localized: "100 g"), 209, 26, 0, 10.9, 0),
        (String(localized: "Turkey breast, sliced"), String(localized: "100 g"), 104, 17, 4, 2, 0),
        (String(localized: "Lean ground beef (93/7), cooked"), String(localized: "100 g"), 182, 25, 0, 8.6, 0),
        (String(localized: "Salmon, baked"), String(localized: "100 g"), 206, 22, 0, 12, 0),
        (String(localized: "Tuna, canned in water"), String(localized: "1 can (120 g)"), 132, 29, 0, 1, 0),
        (String(localized: "Cod, baked"), String(localized: "100 g"), 105, 23, 0, 0.9, 0),
        (String(localized: "Shrimp, cooked"), String(localized: "100 g"), 99, 24, 0.2, 0.3, 0),
        (String(localized: "Tofu, firm"), String(localized: "100 g"), 144, 17, 3, 9, 2),
        (String(localized: "Tempeh"), String(localized: "100 g"), 192, 20, 8, 11, 0),
        (String(localized: "Greek yogurt, plain nonfat"), String(localized: "170 g"), 100, 17, 6, 0.7, 0),
        (String(localized: "Cottage cheese, low fat"), String(localized: "1/2 cup (113 g)"), 90, 12, 5, 2.5, 0),
        (String(localized: "Whey protein powder"), String(localized: "1 scoop (30 g)"), 120, 24, 3, 1.5, 0),
        (String(localized: "Black beans, cooked"), String(localized: "1/2 cup (86 g)"), 114, 7.6, 20, 0.5, 7.5),
        (String(localized: "Chickpeas, cooked"), String(localized: "1/2 cup (82 g)"), 135, 7.3, 22, 2.1, 6),
        (String(localized: "Lentils, cooked"), String(localized: "1/2 cup (99 g)"), 115, 9, 20, 0.4, 7.8),
        (String(localized: "Edamame, shelled"), String(localized: "1/2 cup (78 g)"), 95, 9, 7, 4, 4),
        // Dairy
        (String(localized: "Milk, 2%"), String(localized: "1 cup (244 ml)"), 122, 8, 12, 4.8, 0),
        (String(localized: "Milk, skim"), String(localized: "1 cup (244 ml)"), 83, 8.3, 12, 0.2, 0),
        (String(localized: "Almond milk, unsweetened"), String(localized: "1 cup (240 ml)"), 30, 1, 1, 2.5, 0),
        (String(localized: "Cheddar cheese"), String(localized: "1 oz (28 g)"), 114, 6.5, 0.4, 9.4, 0),
        (String(localized: "Mozzarella, part skim"), String(localized: "1 oz (28 g)"), 72, 6.9, 0.8, 4.5, 0),
        (String(localized: "Feta cheese"), String(localized: "1 oz (28 g)"), 75, 4, 1.2, 6, 0),
        (String(localized: "Butter"), String(localized: "1 tbsp (14 g)"), 102, 0.1, 0, 11.5, 0),
        // Grains & starches
        (String(localized: "Oats, rolled (dry)"), String(localized: "1/2 cup (40 g)"), 150, 5, 27, 3, 4),
        (String(localized: "Brown rice, cooked"), String(localized: "1 cup (195 g)"), 216, 5, 45, 1.8, 3.5),
        (String(localized: "White rice, cooked"), String(localized: "1 cup (158 g)"), 205, 4.3, 45, 0.4, 0.6),
        (String(localized: "Quinoa, cooked"), String(localized: "1 cup (185 g)"), 222, 8, 39, 3.6, 5),
        (String(localized: "Whole wheat bread"), String(localized: "1 slice (43 g)"), 110, 5, 20, 1.5, 3),
        (String(localized: "White bread"), String(localized: "1 slice (30 g)"), 79, 2.7, 15, 1, 0.6),
        (String(localized: "Whole wheat pasta, cooked"), String(localized: "1 cup (140 g)"), 174, 7.5, 37, 0.8, 6),
        (String(localized: "Pasta, cooked"), String(localized: "1 cup (140 g)"), 220, 8, 43, 1.3, 2.5),
        (String(localized: "Sweet potato, baked"), String(localized: "1 medium (150 g)"), 135, 3, 31, 0.2, 5),
        (String(localized: "Potato, baked"), String(localized: "1 medium (173 g)"), 161, 4.3, 37, 0.2, 3.8),
        (String(localized: "Corn tortilla"), String(localized: "1 tortilla (26 g)"), 60, 1.5, 12, 0.7, 1.5),
        (String(localized: "Flour tortilla"), String(localized: "1 tortilla (49 g)"), 146, 4, 25, 3.5, 1.5),
        (String(localized: "Bagel, plain"), String(localized: "1 bagel (105 g)"), 289, 11, 56, 1.7, 2.4),
        (String(localized: "Granola"), String(localized: "1/4 cup (30 g)"), 140, 3, 18, 6, 2),
        (String(localized: "Cereal, bran flakes"), String(localized: "1 cup (30 g)"), 100, 3, 24, 0.5, 5),
        // Fruit
        (String(localized: "Apple"), String(localized: "1 medium (182 g)"), 95, 0.5, 25, 0.3, 4.4),
        (String(localized: "Banana"), String(localized: "1 medium (118 g)"), 105, 1.3, 27, 0.4, 3.1),
        (String(localized: "Orange"), String(localized: "1 medium (131 g)"), 62, 1.2, 15, 0.2, 3.1),
        (String(localized: "Blueberries"), String(localized: "1 cup (148 g)"), 84, 1.1, 21, 0.5, 3.6),
        (String(localized: "Strawberries"), String(localized: "1 cup (152 g)"), 49, 1, 12, 0.5, 3),
        (String(localized: "Grapes"), String(localized: "1 cup (151 g)"), 104, 1.1, 27, 0.2, 1.4),
        (String(localized: "Avocado"), String(localized: "1/2 avocado (68 g)"), 114, 1.3, 6, 10.5, 4.6),
        (String(localized: "Mango"), String(localized: "1 cup (165 g)"), 99, 1.4, 25, 0.6, 2.6),
        (String(localized: "Watermelon"), String(localized: "1 cup (152 g)"), 46, 0.9, 11, 0.2, 0.6),
        (String(localized: "Pear"), String(localized: "1 medium (178 g)"), 101, 0.6, 27, 0.2, 5.5),
        (String(localized: "Raspberries"), String(localized: "1 cup (123 g)"), 64, 1.5, 15, 0.8, 8),
        // Vegetables
        (String(localized: "Broccoli, steamed"), String(localized: "1 cup (156 g)"), 55, 3.7, 11, 0.6, 5),
        (String(localized: "Spinach, raw"), String(localized: "2 cups (60 g)"), 14, 1.7, 2.2, 0.2, 1.3),
        (String(localized: "Mixed salad greens"), String(localized: "2 cups (85 g)"), 20, 1.5, 3.5, 0.3, 2),
        (String(localized: "Carrot"), String(localized: "1 medium (61 g)"), 25, 0.6, 6, 0.1, 1.7),
        (String(localized: "Bell pepper"), String(localized: "1 medium (119 g)"), 31, 1, 7, 0.3, 2.5),
        (String(localized: "Cucumber"), String(localized: "1 cup sliced (104 g)"), 16, 0.7, 3.8, 0.1, 0.5),
        (String(localized: "Tomato"), String(localized: "1 medium (123 g)"), 22, 1.1, 4.8, 0.2, 1.5),
        (String(localized: "Cherry tomatoes"), String(localized: "1 cup (149 g)"), 27, 1.3, 5.8, 0.3, 1.8),
        (String(localized: "Zucchini"), String(localized: "1 medium (196 g)"), 33, 2.4, 6, 0.6, 2),
        (String(localized: "Cauliflower, roasted"), String(localized: "1 cup (124 g)"), 60, 2.3, 6, 3.5, 2.5),
        (String(localized: "Green beans"), String(localized: "1 cup (125 g)"), 44, 2.4, 10, 0.4, 4),
        (String(localized: "Asparagus"), String(localized: "6 spears (90 g)"), 20, 2.2, 3.7, 0.2, 1.8),
        (String(localized: "Onion"), String(localized: "1/2 medium (55 g)"), 22, 0.6, 5, 0.1, 0.9),
        (String(localized: "Mushrooms"), String(localized: "1 cup (70 g)"), 15, 2.2, 2.3, 0.2, 0.7),
        (String(localized: "Kale, raw"), String(localized: "2 cups (40 g)"), 20, 1.7, 3.5, 0.4, 1.4),
        // Fats, nuts, seeds
        (String(localized: "Olive oil"), String(localized: "1 tbsp (14 g)"), 119, 0, 0, 13.5, 0),
        (String(localized: "Almonds"), String(localized: "1 oz (28 g, ~23 nuts)"), 164, 6, 6, 14, 3.5),
        (String(localized: "Walnuts"), String(localized: "1 oz (28 g)"), 185, 4.3, 3.9, 18.5, 1.9),
        (String(localized: "Peanut butter"), String(localized: "1 tbsp (16 g)"), 94, 4, 3.5, 8, 1),
        (String(localized: "Almond butter"), String(localized: "1 tbsp (16 g)"), 98, 3.4, 3, 9, 1.6),
        (String(localized: "Chia seeds"), String(localized: "1 tbsp (12 g)"), 58, 2, 5, 3.7, 4),
        (String(localized: "Flaxseed, ground"), String(localized: "1 tbsp (7 g)"), 37, 1.3, 2, 3, 1.9),
        (String(localized: "Hummus"), String(localized: "2 tbsp (30 g)"), 70, 2, 6, 5, 2),
        // Drinks
        (String(localized: "Coffee, black"), String(localized: "1 cup (240 ml)"), 2, 0.3, 0, 0, 0),
        (String(localized: "Latte, 2% milk"), String(localized: "12 fl oz (355 ml)"), 150, 10, 15, 6, 0),
        (String(localized: "Orange juice"), String(localized: "1 cup (248 ml)"), 112, 1.7, 26, 0.5, 0.5),
        (String(localized: "Cola"), String(localized: "12 fl oz can (355 ml)"), 140, 0, 39, 0, 0),
        (String(localized: "Beer, regular"), String(localized: "12 fl oz (355 ml)"), 153, 1.6, 13, 0, 0),
        (String(localized: "Wine, red"), String(localized: "5 fl oz (148 ml)"), 125, 0.1, 3.8, 0, 0),
        (String(localized: "Protein shake, ready to drink"), String(localized: "1 bottle (325 ml)"), 160, 30, 5, 3, 1),
        // Snacks & convenience
        (String(localized: "Dark chocolate, 70%"), String(localized: "1 oz (28 g)"), 170, 2.2, 13, 12, 3),
        (String(localized: "Rice cakes"), String(localized: "1 cake (9 g)"), 35, 0.7, 7.3, 0.3, 0.4),
        (String(localized: "Protein bar"), String(localized: "1 bar (60 g)"), 210, 20, 22, 7, 5),
        (String(localized: "Popcorn, air-popped"), String(localized: "3 cups (24 g)"), 93, 3, 19, 1.1, 3.6),
        (String(localized: "Tortilla chips"), String(localized: "1 oz (28 g)"), 140, 2, 19, 7, 1),
        (String(localized: "Pizza, cheese"), String(localized: "1 slice (107 g)"), 285, 12, 36, 10, 2.5),
        (String(localized: "Cheeseburger, fast food"), String(localized: "1 burger (150 g)"), 400, 20, 36, 19, 1.5),
        (String(localized: "French fries"), String(localized: "medium (117 g)"), 365, 4, 48, 17, 4),
        (String(localized: "Sushi roll, California"), String(localized: "6 pieces (170 g)"), 255, 9, 38, 7, 3),
        (String(localized: "Chocolate chip cookie"), String(localized: "1 cookie (30 g)"), 148, 1.5, 20, 7, 0.6),
        (String(localized: "Ice cream, vanilla"), String(localized: "1/2 cup (66 g)"), 137, 2.3, 16, 7, 0.5),
        (String(localized: "Honey"), String(localized: "1 tbsp (21 g)"), 64, 0.1, 17, 0, 0),
        (String(localized: "Ketchup"), String(localized: "1 tbsp (17 g)"), 17, 0.2, 4.5, 0, 0),
        (String(localized: "Mayonnaise"), String(localized: "1 tbsp (14 g)"), 94, 0.1, 0.1, 10, 0),
        (String(localized: "Ranch dressing"), String(localized: "2 tbsp (30 g)"), 129, 0.4, 1.8, 13.5, 0),
        (String(localized: "Salsa"), String(localized: "2 tbsp (32 g)"), 9, 0.4, 2, 0, 0.5),
        (String(localized: "Soy sauce"), String(localized: "1 tbsp (16 g)"), 9, 1.3, 0.8, 0, 0),
    ]

    // Chain restaurant items (US menus, from the chains' published nutrition information).
    // chain, name, serving, kcal, protein, carbs, fat, fiber, sodium (mg)
    private static let restaurantTable: [(String, String, String, Double, Double, Double, Double, Double, Double)] = [
        ("McDonald's", "Big Mac", "1 burger", 590, 25, 46, 34, 3, 1050),
        ("McDonald's", "Quarter Pounder with Cheese", "1 burger", 520, 30, 42, 26, 2, 1140),
        ("McDonald's", "McDouble", "1 burger", 400, 22, 33, 20, 2, 920),
        ("McDonald's", "Hamburger", "1 burger", 250, 12, 31, 9, 1, 510),
        ("McDonald's", "McChicken", "1 sandwich", 400, 14, 39, 21, 1, 560),
        ("McDonald's", "Filet-O-Fish", "1 sandwich", 390, 16, 38, 19, 2, 560),
        ("McDonald's", "Chicken McNuggets", "10 pieces", 410, 23, 26, 24, 1, 850),
        ("McDonald's", "French Fries", "medium", 320, 5, 43, 15, 4, 290),
        ("McDonald's", "Egg McMuffin", "1 sandwich", 310, 17, 30, 13, 2, 770),
        ("Chick-fil-A", "Chick-fil-A Chicken Sandwich", "1 sandwich", 420, 29, 41, 18, 1, 1460),
        ("Chick-fil-A", "Chick-fil-A Nuggets", "8 count", 250, 27, 11, 11, 0, 1210),
        ("Chick-fil-A", "Grilled Nuggets", "8 count", 130, 25, 1, 3, 0, 440),
        ("Chick-fil-A", "Waffle Potato Fries", "medium", 420, 5, 45, 24, 5, 240),
        ("Taco Bell", "Crunchy Taco", "1 taco", 170, 8, 13, 10, 3, 310),
        ("Taco Bell", "Soft Taco", "1 taco", 180, 9, 18, 9, 3, 500),
        ("Taco Bell", "Bean Burrito", "1 burrito", 350, 13, 54, 9, 9, 1000),
        ("Taco Bell", "Chicken Quesadilla", "1 quesadilla", 510, 27, 37, 27, 3, 1250),
        ("Taco Bell", "Crunchwrap Supreme", "1 wrap", 530, 16, 71, 21, 6, 1200),
        ("Taco Bell", "Cheesy Gordita Crunch", "1 gordita", 500, 20, 41, 28, 5, 850),
        ("Starbucks", "Caffè Latte, 2% milk", "grande (16 fl oz)", 190, 13, 19, 7, 0, 170),
        ("Starbucks", "Cappuccino, 2% milk", "grande (16 fl oz)", 140, 10, 14, 5, 0, 120),
        ("Starbucks", "Caramel Macchiato, 2% milk", "grande (16 fl oz)", 250, 10, 35, 7, 0, 150),
        ("Starbucks", "Cold Brew", "grande (16 fl oz)", 5, 0, 0, 0, 0, 15),
        ("Starbucks", "Bacon & Gruyère Egg Bites", "2 bites", 300, 19, 9, 20, 0, 680),
        ("Starbucks", "Egg White & Roasted Red Pepper Egg Bites", "2 bites", 170, 12, 11, 8, 1, 470),
        ("Chipotle", "Chipotle Chicken", "4 oz", 180, 32, 0, 7, 0, 310),
        ("Chipotle", "Chipotle Steak", "4 oz", 150, 21, 1, 6, 1, 330),
        ("Chipotle", "Chipotle Barbacoa", "4 oz", 170, 24, 2, 7, 1, 530),
        ("Chipotle", "Chipotle White Rice", "4 oz", 210, 4, 40, 4, 1, 350),
        ("Chipotle", "Chipotle Brown Rice", "4 oz", 210, 4, 36, 6, 2, 190),
        ("Chipotle", "Chipotle Black Beans", "4 oz", 130, 8, 22, 1.5, 7, 210),
        ("Chipotle", "Chipotle Pinto Beans", "4 oz", 130, 8, 21, 1.5, 8, 210),
        ("Chipotle", "Flour Tortilla (burrito)", "1 tortilla", 320, 8, 50, 9, 3, 600),
        ("Chipotle", "Chipotle Guacamole", "4 oz", 230, 2, 8, 22, 6, 370),
        ("Chipotle", "Chipotle Cheese", "1 oz", 110, 6, 1, 8, 0, 190),
        ("Chipotle", "Chipotle Sour Cream", "2 oz", 110, 2, 2, 9, 0, 30),
        ("Chipotle", "Chipotle Fresh Tomato Salsa", "4 oz", 25, 0, 4, 0, 1, 550),
        ("Chipotle", "Chipotle Fajita Veggies", "2 oz", 20, 1, 5, 0, 1, 150),
        ("Chipotle", "Chipotle Chips", "1 bag (4 oz)", 540, 7, 73, 25, 7, 390),
    ]

    static var restaurantFoods: [FoodItem] {
        restaurantTable.map { row in
            FoodItem(name: row.1, brand: row.0, servingDescription: row.2, calories: row.3,
                     protein: row.4, carbs: row.5, fat: row.6, fiber: row.7, sodium: row.8)
        }
    }

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
            Recipe(name: String(localized: "Overnight oats with berries"), mealType: .breakfast, servings: 1, prepMinutes: 5,
                   ingredients: [
                    ing(String(localized: "Rolled oats"), String(localized: "1/2 cup (40 g)"), 150, 5, 27, 3),
                    ing(String(localized: "Greek yogurt, plain nonfat"), String(localized: "1/2 cup (120 g)"), 70, 12, 4, 0.5),
                    ing(String(localized: "Milk, skim"), String(localized: "1/2 cup (120 ml)"), 42, 4, 6, 0.1),
                    ing(String(localized: "Blueberries"), String(localized: "1/2 cup (74 g)"), 42, 0.5, 10, 0.2),
                    ing(String(localized: "Chia seeds"), String(localized: "1 tbsp (12 g)"), 58, 2, 5, 3.7),
                    ing(String(localized: "Honey"), String(localized: "1 tsp (7 g)"), 21, 0, 6, 0),
                   ],
                   instructions: String(localized: "Stir oats, yogurt, milk, chia and honey in a jar. Refrigerate overnight. Top with blueberries before eating."),
                   tags: [String(localized: "High fibre"), String(localized: "Make ahead")]),
            Recipe(name: String(localized: "Veggie egg scramble on toast"), mealType: .breakfast, servings: 1, prepMinutes: 10,
                   ingredients: [
                    ing(String(localized: "Eggs"), String(localized: "2 large"), 144, 12.6, 0.8, 9.6),
                    ing(String(localized: "Spinach"), String(localized: "1 cup (30 g)"), 7, 0.9, 1.1, 0.1),
                    ing(String(localized: "Cherry tomatoes"), String(localized: "1/2 cup (75 g)"), 14, 0.7, 2.9, 0.2),
                    ing(String(localized: "Whole wheat bread"), String(localized: "1 slice (43 g)"), 110, 5, 20, 1.5),
                    ing(String(localized: "Olive oil"), String(localized: "1 tsp (5 g)"), 40, 0, 0, 4.5),
                   ],
                   instructions: String(localized: "Heat oil in a nonstick pan. Wilt spinach and tomatoes for a minute, add beaten eggs and scramble gently. Serve on toast."),
                   tags: [String(localized: "High protein"), String(localized: "Quick")]),
            Recipe(name: String(localized: "Banana protein smoothie"), mealType: .breakfast, servings: 1, prepMinutes: 5,
                   ingredients: [
                    ing(String(localized: "Banana"), String(localized: "1 medium (118 g)"), 105, 1.3, 27, 0.4),
                    ing(String(localized: "Whey protein powder"), String(localized: "1 scoop (30 g)"), 120, 24, 3, 1.5),
                    ing(String(localized: "Almond milk, unsweetened"), String(localized: "1 cup (240 ml)"), 30, 1, 1, 2.5),
                    ing(String(localized: "Peanut butter"), String(localized: "1 tbsp (16 g)"), 94, 4, 3.5, 8),
                    ing(String(localized: "Ice"), String(localized: "handful"), 0, 0, 0, 0),
                   ],
                   instructions: String(localized: "Blend everything until smooth. Add more milk to thin."),
                   tags: [String(localized: "High protein"), String(localized: "Quick")]),
            Recipe(name: String(localized: "Greek yogurt parfait"), mealType: .breakfast, servings: 1, prepMinutes: 3,
                   ingredients: [
                    ing(String(localized: "Greek yogurt, plain nonfat"), String(localized: "170 g"), 100, 17, 6, 0.7),
                    ing(String(localized: "Granola"), String(localized: "1/4 cup (30 g)"), 140, 3, 18, 6),
                    ing(String(localized: "Strawberries"), String(localized: "1/2 cup (76 g)"), 25, 0.5, 6, 0.2),
                   ],
                   instructions: String(localized: "Layer yogurt, granola and berries in a glass."),
                   tags: [String(localized: "Quick")]),

            Recipe(name: String(localized: "Grilled chicken salad"), mealType: .lunch, servings: 1, prepMinutes: 15,
                   ingredients: [
                    ing(String(localized: "Chicken breast, grilled"), String(localized: "120 g"), 198, 37, 0, 4.3),
                    ing(String(localized: "Mixed salad greens"), String(localized: "2 cups (85 g)"), 20, 1.5, 3.5, 0.3),
                    ing(String(localized: "Cherry tomatoes"), String(localized: "1/2 cup (75 g)"), 14, 0.7, 2.9, 0.2),
                    ing(String(localized: "Cucumber"), String(localized: "1/2 cup (52 g)"), 8, 0.3, 1.9, 0.1),
                    ing(String(localized: "Feta cheese"), String(localized: "1 oz (28 g)"), 75, 4, 1.2, 6),
                    ing(String(localized: "Olive oil"), String(localized: "1 tbsp (14 g)"), 119, 0, 0, 13.5),
                    ing(String(localized: "Lemon juice"), String(localized: "1 tbsp"), 4, 0, 1, 0),
                   ],
                   instructions: String(localized: "Season and grill chicken 5–6 minutes a side. Slice over greens, tomatoes and cucumber. Crumble feta, dress with oil and lemon."),
                   tags: [String(localized: "High protein"), String(localized: "Low carb")]),
            Recipe(name: String(localized: "Turkey and avocado wrap"), mealType: .lunch, servings: 1, prepMinutes: 5,
                   ingredients: [
                    ing(String(localized: "Flour tortilla"), String(localized: "1 tortilla (49 g)"), 146, 4, 25, 3.5),
                    ing(String(localized: "Turkey breast, sliced"), String(localized: "85 g"), 88, 14, 3.4, 1.7),
                    ing(String(localized: "Avocado"), String(localized: "1/4 avocado (34 g)"), 57, 0.7, 3, 5.3),
                    ing(String(localized: "Spinach"), String(localized: "1 cup (30 g)"), 7, 0.9, 1.1, 0.1),
                    ing(String(localized: "Tomato"), String(localized: "1/2 medium (62 g)"), 11, 0.5, 2.4, 0.1),
                    ing(String(localized: "Hummus"), String(localized: "1 tbsp (15 g)"), 35, 1, 3, 2.5),
                   ],
                   instructions: String(localized: "Spread hummus on the tortilla, layer turkey, avocado, spinach and tomato. Roll tightly and halve."),
                   tags: [String(localized: "Quick"), String(localized: "Packable")]),
            Recipe(name: String(localized: "Lentil and vegetable soup"), mealType: .lunch, servings: 4, prepMinutes: 35,
                   ingredients: [
                    ing(String(localized: "Lentils, dry"), String(localized: "1 cup (190 g)"), 670, 48, 115, 2),
                    ing(String(localized: "Carrot"), String(localized: "2 medium (122 g)"), 50, 1.2, 12, 0.2),
                    ing(String(localized: "Onion"), String(localized: "1 medium (110 g)"), 44, 1.2, 10, 0.2),
                    ing(String(localized: "Celery"), String(localized: "2 stalks (80 g)"), 13, 0.6, 2.4, 0.1),
                    ing(String(localized: "Canned tomatoes"), String(localized: "1 can (400 g)"), 80, 4, 16, 0.8),
                    ing(String(localized: "Olive oil"), String(localized: "1 tbsp (14 g)"), 119, 0, 0, 13.5),
                    ing(String(localized: "Vegetable stock"), String(localized: "4 cups (1 L)"), 40, 2, 8, 0),
                   ],
                   instructions: String(localized: "Sweat onion, carrot and celery in oil. Add lentils, tomatoes and stock. Simmer 25 minutes until lentils are tender. Season well."),
                   tags: [String(localized: "High fibre"), String(localized: "Batch cook"), String(localized: "Vegan")]),
            Recipe(name: String(localized: "Tuna and white bean salad"), mealType: .lunch, servings: 1, prepMinutes: 8,
                   ingredients: [
                    ing(String(localized: "Tuna, canned in water"), String(localized: "1 can (120 g)"), 132, 29, 0, 1),
                    ing(String(localized: "Cannellini beans"), String(localized: "1/2 cup (90 g)"), 110, 7, 20, 0.5),
                    ing(String(localized: "Red onion"), String(localized: "2 tbsp (20 g)"), 8, 0.2, 2, 0),
                    ing(String(localized: "Olive oil"), String(localized: "2 tsp (9 g)"), 80, 0, 0, 9),
                    ing(String(localized: "Lemon juice"), String(localized: "1 tbsp"), 4, 0, 1, 0),
                    ing(String(localized: "Mixed salad greens"), String(localized: "2 cups (85 g)"), 20, 1.5, 3.5, 0.3),
                   ],
                   instructions: String(localized: "Flake tuna, toss with beans, onion, oil and lemon. Serve over greens."),
                   tags: [String(localized: "High protein"), String(localized: "No cook")]),

            Recipe(name: String(localized: "Salmon with roasted vegetables"), mealType: .dinner, servings: 1, prepMinutes: 25,
                   ingredients: [
                    ing(String(localized: "Salmon fillet"), String(localized: "140 g"), 288, 31, 0, 17),
                    ing(String(localized: "Broccoli"), String(localized: "1 cup (90 g)"), 31, 2.6, 6, 0.4),
                    ing(String(localized: "Sweet potato"), String(localized: "1 small (100 g)"), 90, 2, 21, 0.1),
                    ing(String(localized: "Olive oil"), String(localized: "2 tsp (9 g)"), 80, 0, 0, 9),
                   ],
                   instructions: String(localized: "Toss vegetables with oil, roast at 200°C for 15 minutes. Add salmon to the tray and roast 10–12 minutes more."),
                   tags: [String(localized: "High protein"), String(localized: "One tray")]),
            Recipe(name: String(localized: "Chicken stir-fry with rice"), mealType: .dinner, servings: 2, prepMinutes: 20,
                   ingredients: [
                    ing(String(localized: "Chicken breast"), String(localized: "300 g"), 495, 93, 0, 10.8),
                    ing(String(localized: "Bell pepper"), String(localized: "2 medium (238 g)"), 62, 2, 14, 0.6),
                    ing(String(localized: "Broccoli"), String(localized: "2 cups (180 g)"), 62, 5.2, 12, 0.8),
                    ing(String(localized: "Soy sauce"), String(localized: "2 tbsp (32 g)"), 18, 2.6, 1.6, 0),
                    ing(String(localized: "Garlic and ginger"), String(localized: "1 tbsp"), 10, 0.3, 2, 0),
                    ing(String(localized: "Sesame oil"), String(localized: "2 tsp (9 g)"), 80, 0, 0, 9),
                    ing(String(localized: "Brown rice, cooked"), String(localized: "2 cups (390 g)"), 432, 10, 90, 3.6),
                   ],
                   instructions: String(localized: "Stir-fry sliced chicken in oil until golden. Add vegetables, garlic and ginger, cook 4 minutes. Splash in soy sauce. Serve over rice."),
                   tags: [String(localized: "High protein"), String(localized: "Batch cook")]),
            Recipe(name: String(localized: "Turkey chili"), mealType: .dinner, servings: 4, prepMinutes: 40,
                   ingredients: [
                    ing(String(localized: "Lean ground turkey"), String(localized: "500 g"), 745, 100, 0, 37),
                    ing(String(localized: "Kidney beans, canned"), String(localized: "1 can (400 g)"), 300, 20, 52, 1.6),
                    ing(String(localized: "Canned tomatoes"), String(localized: "1 can (400 g)"), 80, 4, 16, 0.8),
                    ing(String(localized: "Onion"), String(localized: "1 medium (110 g)"), 44, 1.2, 10, 0.2),
                    ing(String(localized: "Bell pepper"), String(localized: "1 medium (119 g)"), 31, 1, 7, 0.3),
                    ing(String(localized: "Olive oil"), String(localized: "1 tbsp (14 g)"), 119, 0, 0, 13.5),
                    ing(String(localized: "Chili spices"), String(localized: "2 tbsp"), 30, 1, 6, 1),
                   ],
                   instructions: String(localized: "Brown turkey with onion and pepper in oil. Add spices, tomatoes and beans. Simmer 25 minutes. Freezes well."),
                   tags: [String(localized: "High protein"), String(localized: "Batch cook")]),
            Recipe(name: String(localized: "Shrimp and zucchini noodles"), mealType: .dinner, servings: 1, prepMinutes: 15,
                   ingredients: [
                    ing(String(localized: "Shrimp, cooked"), String(localized: "150 g"), 149, 36, 0.3, 0.5),
                    ing(String(localized: "Zucchini, spiralised"), String(localized: "2 medium (392 g)"), 66, 4.8, 12, 1.2),
                    ing(String(localized: "Cherry tomatoes"), String(localized: "1 cup (149 g)"), 27, 1.3, 5.8, 0.3),
                    ing(String(localized: "Garlic"), String(localized: "2 cloves"), 9, 0.4, 2, 0),
                    ing(String(localized: "Olive oil"), String(localized: "1 tbsp (14 g)"), 119, 0, 0, 13.5),
                    ing(String(localized: "Parmesan"), String(localized: "1 tbsp (5 g)"), 21, 2, 0, 1.4),
                   ],
                   instructions: String(localized: "Sauté garlic in oil, add tomatoes until they burst. Toss in shrimp and zucchini noodles for 2 minutes. Finish with parmesan."),
                   tags: [String(localized: "Low carb"), String(localized: "Quick")]),
            Recipe(name: String(localized: "Tofu veggie curry with rice"), mealType: .dinner, servings: 2, prepMinutes: 25,
                   ingredients: [
                    ing(String(localized: "Tofu, firm"), String(localized: "300 g"), 432, 51, 9, 27),
                    ing(String(localized: "Light coconut milk"), String(localized: "1 cup (240 ml)"), 150, 1, 4, 14),
                    ing(String(localized: "Curry paste"), String(localized: "2 tbsp"), 40, 1, 6, 1),
                    ing(String(localized: "Cauliflower"), String(localized: "2 cups (200 g)"), 50, 4, 10, 0.6),
                    ing(String(localized: "Green beans"), String(localized: "1 cup (125 g)"), 44, 2.4, 10, 0.4),
                    ing(String(localized: "White rice, cooked"), String(localized: "1.5 cups (237 g)"), 308, 6.4, 67, 0.6),
                   ],
                   instructions: String(localized: "Fry curry paste, add coconut milk and vegetables, simmer 8 minutes. Add cubed tofu and warm through. Serve with rice."),
                   tags: [String(localized: "Vegan"), String(localized: "Batch cook")]),

            Recipe(name: String(localized: "Apple with peanut butter"), mealType: .snack, servings: 1, prepMinutes: 2,
                   ingredients: [
                    ing(String(localized: "Apple"), String(localized: "1 medium (182 g)"), 95, 0.5, 25, 0.3),
                    ing(String(localized: "Peanut butter"), String(localized: "1 tbsp (16 g)"), 94, 4, 3.5, 8),
                   ],
                   instructions: String(localized: "Slice the apple and dip."),
                   tags: [String(localized: "Quick")]),
            Recipe(name: String(localized: "Cottage cheese and berries"), mealType: .snack, servings: 1, prepMinutes: 2,
                   ingredients: [
                    ing(String(localized: "Cottage cheese, low fat"), String(localized: "1/2 cup (113 g)"), 90, 12, 5, 2.5),
                    ing(String(localized: "Raspberries"), String(localized: "1/2 cup (62 g)"), 32, 0.7, 7.5, 0.4),
                   ],
                   instructions: String(localized: "Combine and eat."),
                   tags: [String(localized: "High protein"), String(localized: "Quick")]),
            Recipe(name: String(localized: "Veggies and hummus"), mealType: .snack, servings: 1, prepMinutes: 3,
                   ingredients: [
                    ing(String(localized: "Carrot"), String(localized: "1 medium (61 g)"), 25, 0.6, 6, 0.1),
                    ing(String(localized: "Cucumber"), String(localized: "1/2 cup (52 g)"), 8, 0.3, 1.9, 0.1),
                    ing(String(localized: "Hummus"), String(localized: "3 tbsp (45 g)"), 105, 3, 9, 7.5),
                   ],
                   instructions: String(localized: "Cut vegetables into sticks and dip."),
                   tags: [String(localized: "Vegan"), String(localized: "Quick")]),
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
