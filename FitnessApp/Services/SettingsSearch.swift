import Foundation

/// The pages Settings is split into.
enum SettingsPage: String, CaseIterable, Identifiable, Hashable {
    case profile, nutrition, reminders, healthData, privacy, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: return "Profile & goals"
        case .nutrition: return "Nutrition & targets"
        case .reminders: return "Reminders"
        case .healthData: return "Health & data"
        case .privacy: return "Privacy & security"
        case .about: return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .profile: return "person.crop.circle"
        case .nutrition: return "fork.knife"
        case .reminders: return "bell.badge"
        case .healthData: return "heart.text.square"
        case .privacy: return "lock.shield"
        case .about: return "info.circle"
        }
    }
}

/// Finds individual settings by name or by a related word ("dark mode" → Appearance).
enum SettingsSearch {
    struct Entry: Hashable, Identifiable {
        let title: String
        let page: SettingsPage
        let keywords: [String]

        var id: String { "\(page.rawValue).\(title)" }
    }

    static let entries: [Entry] = [
        Entry(title: "Body & goals", page: .profile,
              keywords: ["name", "sex", "age", "birthday", "height", "weight", "goal weight", "starting weight", "activity", "weekly loss"]),
        Entry(title: "Units", page: .profile, keywords: ["metric", "imperial", "kg", "lb", "stone", "kcal", "kJ", "energy"]),
        Entry(title: "Appearance", page: .profile, keywords: ["dark mode", "light mode", "theme"]),
        Entry(title: "Water goal", page: .profile, keywords: ["hydration", "drink"]),
        Entry(title: "Streak grace day", page: .profile, keywords: ["streak", "missed day"]),

        Entry(title: "Daily calorie target", page: .nutrition, keywords: ["calories", "TDEE", "custom target", "manual"]),
        Entry(title: "Adaptive target", page: .nutrition, keywords: ["measured maintenance", "suggested target"]),
        Entry(title: "Macro split", page: .nutrition, keywords: ["protein", "carbs", "carbohydrates", "fat", "macros"]),
        Entry(title: "Other nutrients", page: .nutrition,
              keywords: ["fibre", "fiber", "sugar", "sodium", "salt", "saturated fat", "potassium", "cholesterol",
                         "alcohol", "caffeine"]),
        Entry(title: "Maintenance mode", page: .nutrition, keywords: ["hold weight", "band"]),
        Entry(title: "Flexible budget", page: .nutrition, keywords: ["weekly budget", "diet break"]),
        Entry(title: "Exercise calories", page: .nutrition, keywords: ["earn back", "workout"]),

        Entry(title: "Morning weigh-in", page: .reminders, keywords: ["notifications", "scale"]),
        Entry(title: "Meal logging reminders", page: .reminders, keywords: ["notifications", "breakfast", "lunch", "dinner"]),
        Entry(title: "Water reminders", page: .reminders, keywords: ["notifications", "hydration"]),
        Entry(title: "Protein check", page: .reminders, keywords: ["notifications"]),
        Entry(title: "Evening check-in", page: .reminders, keywords: ["notifications", "day close"]),

        Entry(title: "Apple Health", page: .healthData, keywords: ["HealthKit", "sync", "steps", "active energy", "import"]),
        Entry(title: "Cycle-aware weight", page: .healthData, keywords: ["period", "menstrual", "water retention"]),
        Entry(title: "iCloud sync", page: .healthData, keywords: ["backup", "devices", "iPad"]),
        Entry(title: "Export and share", page: .healthData, keywords: ["CSV", "PDF", "doctor", "report", "spreadsheet"]),
        Entry(title: "Import CSV", page: .healthData, keywords: ["spreadsheet", "MyFitnessPal", "Lose It"]),
        Entry(title: "Reset all data", page: .healthData, keywords: ["delete", "erase", "start over"]),

        Entry(title: "App lock", page: .privacy, keywords: ["Face ID", "Touch ID", "passcode", "privacy"]),

        Entry(title: "Show feature tips again", page: .about, keywords: ["tips", "help"]),
        Entry(title: "About Stride", page: .about, keywords: ["version", "disclaimer", "medical"]),
    ]

    /// Settings whose title or keywords contain every word of `query`, ignoring case and accents.
    /// Title matches come first; an empty query finds nothing.
    static func search(_ query: String, in entries: [Entry] = entries) -> [Entry] {
        let words = query.split(whereSeparator: \.isWhitespace).map { fold(String($0)) }
        guard !words.isEmpty else { return [] }
        let matches = entries.filter { entry in
            let haystack = fold(([entry.title, entry.page.title] + entry.keywords).joined(separator: " "))
            return words.allSatisfy { haystack.contains($0) }
        }
        let inTitle = matches.filter { entry in words.allSatisfy { fold(entry.title).contains($0) } }
        return inTitle + matches.filter { !inTitle.contains($0) }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
