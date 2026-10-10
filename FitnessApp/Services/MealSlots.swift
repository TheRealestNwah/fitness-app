import Foundation
import Observation

/// A meal in the diary: its name, icon, usual time and how it counts towards the calorie budget.
struct MealSlot: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var icon: String
    var hour: Int
    /// Send a reminder to log this meal.
    var reminds: Bool
    /// Relative weight when splitting the daily budget between meals.
    var share: Double
}

/// The user's meals. The list lives on the profile (so it syncs and backs up) and is mirrored here so
/// `MealType` can read it from anywhere. Reading `slots` in a view body refreshes it when meals change.
@Observable
final class MealSlots: @unchecked Sendable {
    static let shared = MealSlots()

    static let defaults: [MealSlot] = [
        MealSlot(id: "breakfast", name: "Breakfast", icon: "sunrise.fill", hour: 8, reminds: true, share: 0.25),
        MealSlot(id: "lunch", name: "Lunch", icon: "sun.max.fill", hour: 13, reminds: true, share: 0.35),
        MealSlot(id: "dinner", name: "Dinner", icon: "moon.stars.fill", hour: 19, reminds: true, share: 0.30),
        MealSlot(id: "snack", name: "Snacks", icon: "carrot.fill", hour: 16, reminds: false, share: 0.10),
    ]

    /// Icons offered in the editor.
    static let icons = ["sunrise.fill", "sun.max.fill", "moon.stars.fill", "carrot.fill", "cup.and.saucer.fill",
                        "fork.knife", "takeoutbag.and.cup.and.straw.fill", "leaf.fill", "fish.fill",
                        "birthday.cake.fill", "dumbbell.fill", "drop.fill"]

    /// Share given to a slot the user adds.
    static let newSlotShare = 0.15

    var slots: [MealSlot] = MealSlots.defaults

    /// Loads the profile's saved list; an empty or unreadable list means the four defaults.
    func apply(json: String) {
        let decoded = Self.decode(json)
        if decoded != slots { slots = decoded }
    }

    static func decode(_ json: String) -> [MealSlot] {
        guard let data = json.data(using: .utf8), !json.isEmpty,
              let list = try? JSONDecoder().decode([MealSlot].self, from: data) else { return defaults }
        return sanitised(list)
    }

    static func encode(_ slots: [MealSlot]) -> String {
        guard let data = try? JSONEncoder().encode(sanitised(slots)) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Drops duplicates and blank names, clamps hours, and never returns an empty list.
    static func sanitised(_ list: [MealSlot]) -> [MealSlot] {
        var seen = Set<String>()
        var result: [MealSlot] = []
        for var slot in list where !slot.id.isEmpty && !seen.contains(slot.id) {
            seen.insert(slot.id)
            slot.name = slot.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if slot.name.isEmpty { slot.name = defaults.first { $0.id == slot.id }?.name ?? "Meal" }
            slot.hour = min(max(slot.hour, 0), 23)
            if slot.share <= 0 { slot.share = newSlotShare }
            result.append(slot)
        }
        return result.isEmpty ? defaults : result
    }

    /// The slot a free-text meal name from another app best matches: its own name first, then a
    /// default meal's name or common alias, then Snacks (or the last meal when Snacks was removed).
    func closest(to text: String) -> MealType {
        let key = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            if let exact = slots.first(where: { $0.name.lowercased() == key }) { return MealType(id: exact.id) }
            if let prefix = slots.first(where: { key.hasPrefix($0.name.lowercased()) || $0.name.lowercased().hasPrefix(key) }) {
                return MealType(id: prefix.id)
            }
            let aliases: [(String, String)] = [("breakfast", "breakfast"), ("lunch", "lunch"), ("dinner", "dinner"),
                                               ("supper", "dinner"), ("snack", "snack")]
            for (word, id) in aliases where key.hasPrefix(word) && slots.contains(where: { $0.id == id }) {
                return MealType(id: id)
            }
            if let contained = slots.first(where: { key.contains($0.name.lowercased()) }) { return MealType(id: contained.id) }
        }
        if slots.contains(where: { $0.id == "snack" }) { return .snack }
        return MealType(id: slots.last?.id ?? "snack")
    }

    /// The slot's name as written to CSV: the plain id for an unrenamed default, otherwise its name.
    func exportName(for meal: MealType) -> String {
        guard let slot = slots.first(where: { $0.id == meal.rawValue }) else { return meal.rawValue }
        if let original = Self.defaults.first(where: { $0.id == slot.id }), original.name == slot.name { return slot.id }
        return slot.name
    }

    /// A new id for a slot the user adds.
    static func newID() -> String { "meal-" + UUID().uuidString.lowercased().prefix(8) }
}
