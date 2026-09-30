import Foundation
import SwiftData

/// Reads diary and weight history from CSV: Stride's own export (DataExporter) and
/// MyFitnessPal and Lose It! files. Parsing is pure; `apply` adds what isn't already there.
enum DataImporter {
    struct Weight: Equatable {
        var date: Date
        var kg: Double
        var note: String
    }

    struct Food: Equatable {
        var date: Date
        var meal: MealType
        var name: String
        var servings: Double
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var fiber: Double
        var sugar: Double
        var sodiumMg: Double
        var saturatedFat: Double = 0
        var potassiumMg: Double = 0
        var cholesterolMg: Double = 0
        var alcoholG: Double = 0
        var caffeineMg: Double = 0
    }

    struct Preview: Equatable {
        var weights: [Weight] = []
        var food: [Food] = []
        /// Rows that couldn't be read (bad date or number).
        var skipped = 0

        var isEmpty: Bool { weights.isEmpty && food.isEmpty }
    }

    enum ImportError: Error, Equatable, LocalizedError {
        case unrecognised

        var errorDescription: String? {
            "This file doesn't look like a food diary or weight log. It needs a date column and either calories or weight."
        }
    }

    // MARK: CSV

    /// Splits CSV into rows of fields: quoted fields, doubled quotes, commas and line breaks inside quotes.
    static func rows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var chars = Array(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)
        chars.append("\n")
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 } else { quoted = false }
                } else {
                    field.append(c)
                }
            } else if c == "\"" {
                quoted = true
            } else if c == "," {
                row.append(field); field = ""
            } else if c == "\n" || c == "\r\n" || c == "\r" {
                row.append(field); field = ""
                if !(row.count == 1 && row[0].trimmingCharacters(in: .whitespaces).isEmpty) { rows.append(row) }
                row = []
            } else {
                field.append(c)
            }
            i += 1
        }
        return rows
    }

    /// "Protein (g)" → "proteing", "weight_kg" → "weightkg".
    static func key(_ header: String) -> String {
        header.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    // MARK: Values

    static func date(_ text: String, defaultHour: Int, calendar: Calendar = .current) -> Date? {
        let text = text.trimmingCharacters(in: .whitespaces)
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: text) { return d }
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "M/d/yyyy", "M/d/yy"] {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.calendar = calendar
            f.timeZone = calendar.timeZone
            f.dateFormat = format
            if let d = f.date(from: text) {
                return format.contains("HH") ? d : calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: d)
            }
        }
        return nil
    }

    static func number(_ text: String?) -> Double? {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        return Double(text.replacingOccurrences(of: ",", with: ""))
    }

    static func isTrue(_ text: String?) -> Bool {
        ["true", "yes", "1"].contains(key(text ?? ""))
    }

    static func meal(_ text: String) -> MealType {
        let k = key(text)
        if k.hasPrefix("breakfast") { return .breakfast }
        if k.hasPrefix("lunch") { return .lunch }
        if k.hasPrefix("dinner") || k.hasPrefix("supper") { return .dinner }
        return .snack
    }

    private static func mealHour(_ meal: MealType) -> Int {
        switch meal {
        case .breakfast: 8
        case .lunch: 12
        case .dinner: 19
        case .snack: 15
        }
    }

    // MARK: Parse

    /// `plainWeightUnit` is what a bare "weight" column is in (the user's weight unit).
    static func preview(csv text: String, plainWeightUnit: WeightUnit = .kg) throws -> Preview {
        let all = rows(text)
        guard let header = all.first else { throw ImportError.unrecognised }
        let keys = header.map(key)
        func column(_ names: String...) -> Int? { names.lazy.compactMap { keys.firstIndex(of: $0) }.first }

        guard let dateCol = column("date", "day", "datetime") else { throw ImportError.unrecognised }
        let weightCols: [(Int, Double)] = [
            column("weightkg", "weightkgs").map { ($0, 1.0) },
            column("weightlb", "weightlbs", "weightpounds").map { ($0, 0.45359237) },
            column("weight", "bodyweight").map { ($0, plainWeightUnit == .kg ? 1.0 : 0.45359237) },
        ].compactMap { $0 }
        let calCol = column("calories", "energykcal", "kcal", "caloriesconsumed")
        guard !weightCols.isEmpty || calCol != nil else { throw ImportError.unrecognised }

        // Lose It! keeps deleted entries in its export, flagged in a "Deleted" column.
        let deletedCol = column("deleted")

        var preview = Preview()
        for row in all.dropFirst() {
            func value(_ index: Int?) -> String? { index.flatMap { $0 < row.count ? row[$0] : nil } }
            if isTrue(value(deletedCol)) { continue }
            if let weightCol = weightCols.first, calCol == nil {
                guard let kg = number(value(weightCol.0)).map({ $0 * weightCol.1 }), (20...400).contains(kg),
                      let when = date(value(dateCol) ?? "", defaultHour: 7) else { preview.skipped += 1; continue }
                preview.weights.append(Weight(date: when, kg: (kg * 100).rounded() / 100,
                                              note: value(column("note", "notes")) ?? ""))
            } else if let calCol {
                let mealType = meal(value(column("meal", "mealtype", "type")) ?? "")
                guard let calories = number(value(calCol)), calories >= 0,
                      let when = date(value(dateCol) ?? "", defaultHour: mealHour(mealType)) else { preview.skipped += 1; continue }
                let name = value(column("food", "foodname", "name", "item", "description"))?
                    .trimmingCharacters(in: .whitespaces)
                preview.food.append(Food(
                    date: when, meal: mealType,
                    name: (name?.isEmpty ?? true) ? "\(mealType.rawValue.capitalized) (imported)" : name!,
                    servings: number(value(column("servings", "quantity"))) ?? 1,
                    calories: calories,
                    protein: number(value(column("proteing", "protein"))) ?? 0,
                    carbs: number(value(column("carbsg", "carbs", "carbohydratesg", "carbohydrates"))) ?? 0,
                    fat: number(value(column("fatg", "fat", "totalfatg"))) ?? 0,
                    fiber: number(value(column("fiberg", "fiber", "fibreg", "fibre"))) ?? 0,
                    sugar: number(value(column("sugarg", "sugarsg", "sugar", "sugars"))) ?? 0,
                    sodiumMg: number(value(column("sodiummg", "sodium"))) ?? 0,
                    saturatedFat: number(value(column("saturatedfatg", "saturatedfat"))) ?? 0,
                    potassiumMg: number(value(column("potassiummg", "potassium"))) ?? 0,
                    cholesterolMg: number(value(column("cholesterolmg", "cholesterol"))) ?? 0,
                    alcoholG: number(value(column("alcoholg", "alcohol"))) ?? 0,
                    caffeineMg: number(value(column("caffeinemg", "caffeine"))) ?? 0))
            }
        }
        return preview
    }

    // MARK: Apply

    /// Leaves out rows already in the store: a weigh-in on the same day within 0.05 kg,
    /// or a diary line with the same minute, name and calories.
    @MainActor
    static func withoutDuplicates(_ preview: Preview, context: ModelContext) -> Preview {
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        let food = (try? context.fetch(FetchDescriptor<FoodLogEntry>())) ?? []
        let cal = Calendar.current
        func minute(_ d: Date) -> Int { Int(d.timeIntervalSince1970 / 60) }
        let foodKeys = Set(food.map { "\(minute($0.date))|\($0.foodName)|\(Int($0.calories.rounded()))" })
        var result = preview
        result.weights = preview.weights.filter { new in
            !weights.contains { cal.isDate($0.date, inSameDayAs: new.date) && abs($0.weightKg - new.kg) < 0.05 }
        }
        var seen = foodKeys
        result.food = preview.food.filter { new in
            seen.insert("\(minute(new.date))|\(new.name)|\(Int(new.calories.rounded()))").inserted
        }
        return result
    }

    /// Adds the rows. History isn't mirrored to Apple Health, which would flood it.
    @MainActor
    static func apply(_ preview: Preview, context: ModelContext) throws {
        for w in preview.weights {
            context.insert(WeightEntry(date: w.date, weightKg: w.kg, note: w.note))
        }
        for f in preview.food {
            let entry = FoodLogEntry(date: f.date, mealType: f.meal, foodName: f.name, servings: f.servings,
                                     servingDescription: "imported", calories: f.calories, protein: f.protein,
                                     carbs: f.carbs, fat: f.fat, fiber: f.fiber, sugar: f.sugar, sodium: f.sodiumMg)
            entry.saturatedFat = f.saturatedFat
            entry.potassium = f.potassiumMg
            entry.cholesterol = f.cholesterolMg
            entry.alcohol = f.alcoholG
            entry.caffeine = f.caffeineMg
            context.insert(entry)
        }
        try context.save()
    }
}
