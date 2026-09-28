import Foundation

/// Writes the user's logs to CSV files in the temporary directory so they can be shared.
enum DataExporter {
    private static var isoFormatter: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }

    private static func escape(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return text
    }

    private static func write(_ csv: String, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func exportWeights(_ entries: [WeightEntry]) throws -> URL {
        var lines = ["date,weight_kg,note"]
        for e in entries.sorted(by: { $0.date < $1.date }) {
            lines.append("\(isoFormatter.string(from: e.date)),\(e.weightKg),\(escape(e.note))")
        }
        return try write(lines.joined(separator: "\n"), name: "weight.csv")
    }

    static func exportFoodLog(_ entries: [FoodLogEntry]) throws -> URL {
        var lines = ["date,meal,food,servings,calories,protein_g,carbs_g,fat_g,fiber_g,sugar_g,sodium_mg,"
                     + "saturated_fat_g,potassium_mg,cholesterol_mg"]
        for e in entries.sorted(by: { $0.date < $1.date }) {
            lines.append([isoFormatter.string(from: e.date), e.mealType.rawValue, escape(e.foodName),
                          String(e.servings), String(e.calories), String(e.protein), String(e.carbs), String(e.fat),
                          String(e.fiber), String(e.sugar), String(e.sodium),
                          String(e.saturatedFat), String(e.potassium), String(e.cholesterol)]
                .joined(separator: ","))
        }
        return try write(lines.joined(separator: "\n"), name: "food-log.csv")
    }

    static func exportVitals(_ entries: [VitalsEntry]) throws -> URL {
        var lines = ["date,systolic,diastolic,resting_hr,body_fat_pct,waist_cm,hip_cm,chest_cm,sleep_h,glucose_mgdl,note"]
        func s(_ v: Int?) -> String { v.map(String.init) ?? "" }
        func d(_ v: Double?) -> String { v.map { String($0) } ?? "" }
        for e in entries.sorted(by: { $0.date < $1.date }) {
            lines.append([isoFormatter.string(from: e.date), s(e.systolic), s(e.diastolic), s(e.restingHeartRate),
                          d(e.bodyFatPercent), d(e.waistCm), d(e.hipCm), d(e.chestCm), d(e.sleepHours),
                          d(e.bloodGlucose), escape(e.note)].joined(separator: ","))
        }
        return try write(lines.joined(separator: "\n"), name: "vitals.csv")
    }
}
