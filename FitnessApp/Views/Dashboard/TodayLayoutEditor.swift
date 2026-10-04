import SwiftUI

/// Reorder and hide Today's cards. Changes save as they're made.
struct TodayLayoutEditor: View {
    @AppStorage(TodayLayoutEditor.storageKey) private var storage = ""
    @Environment(\.dismiss) private var dismiss

    static let storageKey = "todayLayout"

    private var layout: TodayLayout { TodayLayout(storage: storage) }

    private func update(_ change: (inout TodayLayout) -> Void) {
        var copy = layout
        change(&copy)
        storage = copy.storage
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(layout.order) { card in
                        Toggle(isOn: Binding(get: { !layout.hidden.contains(card) },
                                             set: { on in update { $0.setVisible(card, on) } })) {
                            Label(card.title, systemImage: card.systemImage)
                        }
                    }
                    .onMove { source, destination in
                        update { $0.move(fromOffsets: source, toOffset: destination) }
                    }
                } footer: {
                    Text("Drag to reorder. Some cards also hide themselves when there's nothing to show, like Activity without Apple Health.")
                }
                Section {
                    Button("Reset to default") { storage = TodayLayout.default.storage }
                        .disabled(layout.isDefault)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Customise Today")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
