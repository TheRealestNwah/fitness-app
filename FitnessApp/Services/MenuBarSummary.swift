import Foundation

/// What the Mac menu bar extra shows and offers, kept apart from the view so it can be tested.
enum MenuBarSummary {
    /// Whether the menu bar extra is in the menu bar. On unless turned off in Settings.
    static let enabledKey = "menuBarExtraEnabled"

    /// How many foods the extra offers for one-click logging.
    static let foodLimit = 6

    struct Food: Equatable {
        var id: UUID
        var isFavorite: Bool
        var useCount: Int
        var lastUsed: Date?
    }

    /// "420 kcal left", or "120 kcal over" once the target is passed.
    static func caloriesLine(remainingKcal: Double) -> String {
        let amount = Energy.string(abs(remainingKcal))
        return remainingKcal >= 0 ? String(localized: "\(amount) left") : String(localized: "\(amount) over")
    }

    /// "62 of 120 g protein", or just the total when there's no target.
    static func proteinLine(grams: Double, targetGrams: Double?) -> String {
        let eaten = Int(grams.rounded())
        guard let target = targetGrams, target > 0 else { return String(localized: "\(eaten) g protein") }
        return String(localized: "\(eaten) of \(Int(target.rounded())) g protein")
    }

    /// "750 of 2,000 ml water" in the user's units is the view's job; this is the share of the goal, 0...1.
    static func waterProgress(ml: Double, goalMl: Double) -> Double {
        guard goalMl > 0 else { return 0 }
        return min(max(ml / goalMl, 0), 1)
    }

    /// Favourites first (most used first), then other foods by how recently they were used.
    static func quickFoods(_ foods: [Food], limit: Int = foodLimit) -> [UUID] {
        let favourites = foods.filter(\.isFavorite).sorted {
            if $0.useCount != $1.useCount { return $0.useCount > $1.useCount }
            return ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast)
        }
        let others = foods.filter { !$0.isFavorite && $0.useCount > 0 }.sorted {
            ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast)
        }
        return (favourites + others).prefix(limit).map(\.id)
    }
}
