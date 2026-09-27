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
        } else if isNearMiss(query, name) {
            score = 15
        } else {
            return nil
        }
        if candidate.isFavorite { score += favoriteBonus }
        if let lastUsed = candidate.lastUsed, now.timeIntervalSince(lastUsed) < Double(recentDays) * 86_400 {
            score += recentBonus
        }
        return score
    }

    /// A typo away: every word of the query (4+ letters) is within one edit of the start of
    /// some word in the name ("chiken" → "chicken", "banan" → "banana", "yoghurt" → "yogurt").
    static func isNearMiss(_ query: String, _ name: String) -> Bool {
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let terms = query.split(separator: " ").map(String.init)
        guard !terms.isEmpty, terms.allSatisfy({ $0.count >= 4 }) else { return false }
        return terms.allSatisfy { term in
            words.contains { word in
                let prefix = String(word.prefix(term.count + 1))
                return editDistance(term, prefix, limit: 1) <= 1
                    || editDistance(term, String(word.prefix(term.count)), limit: 1) <= 1
            }
        }
    }

    /// Levenshtein distance, giving up once it exceeds `limit`.
    static func editDistance(_ a: String, _ b: String, limit: Int) -> Int {
        let a = Array(a), b = Array(b)
        if abs(a.count - b.count) > limit { return limit + 1 }
        var previous = Array(0...b.count)
        for i in 1...max(a.count, 1) where !a.isEmpty {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...max(b.count, 1) where !b.isEmpty {
                current[j] = min(previous[j] + 1, current[j - 1] + 1,
                                 previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            if current.min()! > limit { return limit + 1 }
            previous = current
        }
        return a.isEmpty ? b.count : previous[b.count]
    }

    /// Matching items, best first; ties keep their original order.
    static func rank<T>(_ items: [T], query: String, now: Date = .now, candidate: (T) -> Candidate) -> [T] {
        items.enumerated()
            .compactMap { index, item in score(candidate(item), query: query, now: now).map { (index, item, $0) } }
            .sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }
            .map(\.1)
    }
}

/// The last few food searches, newest first, stored as newline-separated text.
enum RecentSearches {
    static let storageKey = "recentFoodSearches"
    static let limit = 8

    static func list(_ storage: String) -> [String] {
        storage.split(separator: "\n").map(String.init)
    }

    static func adding(_ term: String, to storage: String) -> String {
        let term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else { return storage }
        let rest = list(storage).filter { $0.lowercased() != term.lowercased() }
        return ([term] + rest).prefix(limit).joined(separator: "\n")
    }
}
