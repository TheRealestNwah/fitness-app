import Foundation

/// A card on the Today screen that can be reordered or hidden.
enum TodayCard: String, CaseIterable, Identifiable {
    case calories, quickActions, suggestions, weight, progress, activity, exercise, weeklyReview, water, fasting, plan, vitals, tip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calories: String(localized: "Calories")
        case .quickActions: String(localized: "Quick actions")
        case .suggestions: String(localized: "Fits what's left")
        case .weight: String(localized: "Weight")
        case .progress: String(localized: "Milestones and plateaus")
        case .activity: String(localized: "Activity")
        case .exercise: String(localized: "Exercise")
        case .weeklyReview: String(localized: "Last 7 days")
        case .water: String(localized: "Water")
        case .fasting: String(localized: "Fasting")
        case .plan: String(localized: "Today's plan")
        case .vitals: String(localized: "Vitals")
        case .tip: String(localized: "Tip of the day")
        }
    }

    var systemImage: String {
        switch self {
        case .calories: "flame.fill"
        case .quickActions: "plus.circle.fill"
        case .suggestions: "sparkles"
        case .weight: "scalemass.fill"
        case .progress: "trophy.fill"
        case .activity: "figure.walk"
        case .exercise: "figure.run"
        case .weeklyReview: "calendar.badge.clock"
        case .water: "drop.fill"
        case .fasting: "timer"
        case .plan: "calendar"
        case .vitals: "heart.text.square.fill"
        case .tip: "lightbulb.fill"
        }
    }
}

/// Order and visibility of the Today cards, stored as a short string in user defaults.
struct TodayLayout: Equatable {
    var order: [TodayCard]
    var hidden: Set<TodayCard>

    static let `default` = TodayLayout(order: TodayCard.allCases, hidden: [])

    /// Cards to show, in order. Some also hide themselves when they have nothing to say.
    var visible: [TodayCard] { order.filter { !hidden.contains($0) } }

    var isDefault: Bool { self == .default }

    /// Two columns for wide layouts, alternating so each keeps the chosen order top to bottom.
    static func columns(_ cards: [TodayCard]) -> (left: [TodayCard], right: [TodayCard]) {
        let indexed = cards.enumerated()
        return (indexed.filter { $0.offset.isMultiple(of: 2) }.map(\.element),
                indexed.filter { !$0.offset.isMultiple(of: 2) }.map(\.element))
    }

    // MARK: Storage

    /// "order|hidden", each a comma-separated list of raw values.
    var storage: String {
        order.map(\.rawValue).joined(separator: ",") + "|"
            + TodayCard.allCases.filter { hidden.contains($0) }.map(\.rawValue).joined(separator: ",")
    }

    /// Reads `storage`, ignoring unknown cards and slotting in any added since it was saved
    /// at their default position, so an update never loses a card.
    init(storage: String) {
        let parts = storage.split(separator: "|", omittingEmptySubsequences: false)
        func cards(_ index: Int) -> [TodayCard] {
            guard index < parts.count else { return [] }
            return parts[index].split(separator: ",").compactMap { TodayCard(rawValue: String($0)) }
        }
        var order: [TodayCard] = []
        for card in cards(0) where !order.contains(card) { order.append(card) }
        for card in TodayCard.allCases where !order.contains(card) {
            // After the card that precedes it by default, or first.
            let defaults = TodayCard.allCases
            let before = defaults[..<defaults.firstIndex(of: card)!].last { order.contains($0) }
            let at = before.flatMap { order.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
            order.insert(card, at: at)
        }
        self.init(order: order, hidden: Set(cards(1)))
    }

    init(order: [TodayCard], hidden: Set<TodayCard>) {
        self.order = order
        self.hidden = hidden
    }

    // MARK: Editing

    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { order[$0] }
        let before = order[..<min(destination, order.count)].filter { !moving.contains($0) }.count
        order.removeAll { moving.contains($0) }
        order.insert(contentsOf: moving, at: before)
    }

    mutating func setVisible(_ card: TodayCard, _ visible: Bool) {
        if visible { hidden.remove(card) } else { hidden.insert(card) }
    }
}
