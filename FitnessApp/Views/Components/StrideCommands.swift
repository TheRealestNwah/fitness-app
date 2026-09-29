import SwiftUI

/// What the menu bar and keyboard shortcuts can do in the focused window.
struct SceneActions {
    var select: (MainTabView.Tab) -> Void
    var logFood: () -> Void
    var logWeight: () -> Void
    var logWater: () -> Void
    var openSettings: () -> Void
}

/// Previous and next day, while the Food diary is showing.
struct DiaryDayActions {
    var previous: () -> Void
    /// Nil on today: the diary doesn't go into the future.
    var next: (() -> Void)?
}

private struct SceneActionsKey: FocusedValueKey {
    typealias Value = SceneActions
}

private struct DiaryDayActionsKey: FocusedValueKey {
    typealias Value = DiaryDayActions
}

extension FocusedValues {
    var sceneActions: SceneActions? {
        get { self[SceneActionsKey.self] }
        set { self[SceneActionsKey.self] = newValue }
    }

    var diaryDayActions: DiaryDayActions? {
        get { self[DiaryDayActionsKey.self] }
        set { self[DiaryDayActionsKey.self] = newValue }
    }
}

/// Menu bar commands (iPadOS menu bar and the ⌘-hold overlay on a hardware keyboard).
struct StrideCommands: Commands {
    @FocusedValue(\.sceneActions) private var actions
    @FocusedValue(\.diaryDayActions) private var diary

    private static let sectionKeys: [KeyEquivalent] = ["1", "2", "3", "4", "5"]

    var body: some Commands {
        // ⌘N logs food rather than opening a new window.
        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { actions?.openSettings() }
                .keyboardShortcut(",")
                .disabled(actions == nil)
        }
        // ⌘Z is the system Edit › Undo: UndoCenter registers each delete with the window's UndoManager.
        CommandMenu("Log") {
            Group {
                // Opens food search with its search field; ⌘F stays the system Find.
                Button("Log Food") { actions?.logFood() }
                    .keyboardShortcut("n")
                Button("Weigh In") { actions?.logWeight() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                Button("Log Water") { actions?.logWater() }
                    .keyboardShortcut("l")
            }
            .disabled(actions == nil)
        }
        CommandMenu("Go") {
            ForEach(Array(zip(MainTabView.Tab.allCases, Self.sectionKeys)), id: \.0) { tab, key in
                Button(tab.title) { actions?.select(tab) }
                    .keyboardShortcut(key)
                    .disabled(actions == nil)
            }
            Divider()
            Button("Previous Day") { diary?.previous() }
                .keyboardShortcut("[")
                .disabled(diary == nil)
            Button("Next Day") { diary?.next?() }
                .keyboardShortcut("]")
                .disabled(diary?.next == nil)
        }
    }
}
