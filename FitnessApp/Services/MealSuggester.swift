import Foundation

/// "What can I still eat?": ranks foods, saved meals and recipes by how well they fit
/// what's left of today's calories and macros.
enum MealSuggester {
    struct Macros: Equatable {
        var kcal: Double
        var protein: Double
        var carbs: Double
        var fat: Double
    }

    enum Kind: Equatable {
        case food(UUID)
        case meal(UUID)
        case recipe(UUID)
    }

    struct Candidate: Equatable {
        var kind: Kind
        var name: String
        var detail: String
        var macros: Macros
    }

    /// Nothing to suggest below this many calories left.
    static let minimumRemaining: Double = 100

    /// Best fits first. Anything over the remaining calories (with a little slack) is left out.
    /// A candidate scores for filling the macro gaps, weighted towards whichever macro is furthest
    /// behind, and loses for overshooting a macro or for being a token amount.
    static func suggestions(remaining: Macros, target: Macros, candidates: [Candidate], limit: Int = 4) -> [Candidate] {
        guard remaining.kcal >= minimumRemaining else { return [] }
        let gaps: [(gap: Double, target: Double, path: KeyPath<Macros, Double>)] = [
            (max(remaining.protein, 0), max(target.protein, 1), \Macros.protein),
            (max(remaining.carbs, 0), max(target.carbs, 1), \Macros.carbs),
            (max(remaining.fat, 0), max(target.fat, 1), \Macros.fat),
        ]
        // Share of each macro's daily target still to go: the furthest behind counts most.
        let behind: [Double] = gaps.map { $0.gap / $0.target }
        let totalBehind = max(behind.reduce(0, +), 0.0001)

        func score(_ c: Candidate) -> Double {
            var fill = 0.0, overshoot = 0.0
            for (i, gap) in gaps.enumerated() {
                let amount: Double = max(c.macros[keyPath: gap.path], 0)
                let covered: Double = gap.gap > 0 ? min(amount, gap.gap) / gap.gap : 0
                fill += (behind[i] / totalBehind) * covered
                overshoot += max(amount - gap.gap, 0) / gap.target
            }
            let share = c.macros.kcal / remaining.kcal
            let tokenPenalty = share < 0.15 ? (0.15 - share) * 2 : 0
            return fill - overshoot - tokenPenalty
        }

        let ceiling = remaining.kcal * 1.05 + 25
        let fitting = candidates.filter { $0.macros.kcal > 0 && $0.macros.kcal <= ceiling }
        let scored: [(candidate: Candidate, score: Double)] = fitting.map { ($0, score($0)) }
        let ranked = scored.sorted { a, b in
            a.score != b.score ? a.score > b.score : a.candidate.name < b.candidate.name
        }
        var seen = Set<String>()
        var picks: [Candidate] = []
        for entry in ranked where picks.count < limit {
            if seen.insert(entry.candidate.name.lowercased()).inserted { picks.append(entry.candidate) }
        }
        return picks
    }
}
