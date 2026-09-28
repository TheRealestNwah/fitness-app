import EventKit
import Foundation

/// Sends the grocery list to a list in Apple Reminders, so it can be shared and ticked off in
/// the store. Sending again updates that list instead of adding duplicates.
enum GroceryReminders {
    static let listTitle = String(localized: "Groceries")
    /// Marks reminders Stride created, so a later send only replaces its own.
    static let tag = URL(string: "stride://grocery")!

    struct Line: Equatable {
        var title: String
        var notes: String
    }

    struct Existing: Equatable {
        var id: String
        var title: String
        var notes: String
        var isOurs: Bool
    }

    struct Changes: Equatable {
        var add: [Line] = []
        var update: [(id: String, notes: String)] = []
        var remove: [String] = []

        static func == (a: Changes, b: Changes) -> Bool {
            a.add == b.add && a.remove == b.remove
                && a.update.map(\.id) == b.update.map(\.id) && a.update.map(\.notes) == b.update.map(\.notes)
        }
    }

    /// What to change in the list's open reminders to match `lines`. Items with the same title
    /// (any case) are kept and get new notes; Stride's own that are no longer needed go; ones the
    /// user added by hand are left alone.
    static func changes(existing: [Existing], lines: [Line]) -> Changes {
        var changes = Changes()
        var byTitle: [String: Existing] = [:]
        for item in existing { byTitle[item.title.lowercased()] = byTitle[item.title.lowercased()] ?? item }
        let wanted = Set(lines.map { $0.title.lowercased() })
        for line in lines {
            if let match = byTitle[line.title.lowercased()] {
                if match.notes != line.notes { changes.update.append((match.id, line.notes)) }
            } else {
                changes.add.append(line)
            }
        }
        changes.remove = existing.filter { $0.isOurs && !wanted.contains($0.title.lowercased()) }.map(\.id)
        return changes
    }

    enum SendError: LocalizedError {
        case denied
        var errorDescription: String? {
            String(localized: "Stride doesn't have access to Reminders. You can allow it in iOS Settings → Stride.")
        }
    }

    /// Sends the lines and returns how many are on the list afterwards.
    static func send(_ lines: [Line]) async throws -> Int {
        let store = EKEventStore()
        guard try await store.requestFullAccessToReminders() else { throw SendError.denied }
        let list = try groceryList(in: store)
        let open = try await incompleteReminders(in: list, store: store)
        let plan = changes(existing: open.map {
            Existing(id: $0.calendarItemIdentifier, title: $0.title ?? "", notes: $0.notes ?? "", isOurs: $0.url == tag)
        }, lines: lines)

        for line in plan.add {
            let reminder = EKReminder(eventStore: store)
            reminder.calendar = list
            reminder.title = line.title
            reminder.notes = line.notes
            reminder.url = tag
            try store.save(reminder, commit: false)
        }
        for update in plan.update {
            if let reminder = open.first(where: { $0.calendarItemIdentifier == update.id }) {
                reminder.notes = update.notes
                try store.save(reminder, commit: false)
            }
        }
        for id in plan.remove {
            if let reminder = open.first(where: { $0.calendarItemIdentifier == id }) {
                try store.remove(reminder, commit: false)
            }
        }
        try store.commit()
        return lines.count
    }

    private static func groceryList(in store: EKEventStore) throws -> EKCalendar {
        if let existing = store.calendars(for: .reminder).first(where: { $0.title == listTitle }) { return existing }
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = listTitle
        guard let source = store.defaultCalendarForNewReminders()?.source
                ?? store.sources.first(where: { $0.sourceType == .local }) else { throw SendError.denied }
        list.source = source
        try store.saveCalendar(list, commit: true)
        return list
    }

    private static func incompleteReminders(in list: EKCalendar, store: EKEventStore) async throws -> [EKReminder] {
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [list])
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { continuation.resume(returning: $0 ?? []) }
        }
    }
}
