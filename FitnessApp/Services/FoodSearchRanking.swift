import Foundation

/// Orders search results so the most likely pick comes first: name matches beat
/// brand or ingredient matches, and favourites and recently used foods beat
/// generic ones with an equally good match.
enum FoodSearchRanking {
    struct Candidate {
        var name: String
        /// Brand, barcode, a meal's slot or its foods: matched, but weaker than the name.
        var other: [String] = []
        var isFavorite = false
        var lastUsed: Date?
    }

    static let favoriteBonus = 30
    static let recentBonus = 10
    static let recentDays = 30

    /// nil when nothing matches.
    static func score(_ candidate: Candidate, query: String, now: Date = .now) -> Int? {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return 0 }
        let name = candidate.name.lowercased()
        var score: Int
        if name == query {
            score = 100
        } else if name.hasPrefix(query) {
            score = 80
        } else if name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains(where: { $0.hasPrefix(query) }) {
            score = 60
        } else if name.contains(query) {
            score = 40
        } else if candidate.other.contains(where: { $0.lowercased().contains(query) }) {
            score = 20
        } else {
            return nil
        }
        if candidate.isFavorite { score += favoriteBonus }
        if let lastUsed = candidate.lastUsed, now.timeIntervalSince(lastUsed) < Double(recentDays) * 86_400 {
            score += recentBonus
        }
        return score
    }

    /// Matching items, best first; ties keep their original order.
    static func rank<T>(_ items: [T], query: String, now: Date = .now, candidate: (T) -> Candidate) -> [T] {
        items.enumerated()
            .compactMap { index, item in score(candidate(item), query: query, now: now).map { (index, item, $0) } }
            .sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }
            .map(\.1)
    }
}
