#if os(macOS)
import SwiftUI
import SwiftData
import AppKit

/// The window shown from the Mac menu bar extra: today's numbers and quick ways to log.
struct MenuBarExtraContent: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppLock.enabledKey) private var lockEnabled = false
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<FoodItem> { $0.isFavorite || $0.useCount > 0 })
    private var foods: [FoodItem]
    @State private var snapshot: WidgetSnapshot?

    private var quickFoods: [FoodItem] {
        let ids = MenuBarSummary.quickFoods(foods.map {
            MenuBarSummary.Food(id: $0.uuid, isFavorite: $0.isFavorite, useCount: $0.useCount, lastUsed: $0.lastUsed)
        })
        return ids.compactMap { id in foods.first { $0.uuid == id } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if lockEnabled {
                // The app lock state lives in the main window, so with it on the extra shows nothing private.
                Text("Stride is protected by the app lock. Open Stride to unlock it.")
                    .foregroundStyle(Color.secondary)
            } else if let snapshot {
                summary(snapshot)
                Divider()
                actions(snapshot)
            } else {
                Text("Open Stride to finish setting up.")
                    .foregroundStyle(Color.secondary)
            }
            Divider()
            Button("Open Stride") { openMainWindow() }
        }
        .padding(14)
        .frame(width: 280)
        .accessibilityIdentifier("menuBarExtra")
        .onAppear(perform: refresh)
        .onChange(of: profiles.count) { refresh() }
    }

    private func summary(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(MenuBarSummary.caloriesLine(remainingKcal: snapshot.remainingKcal))
                .font(.title3.bold())
            Text(MenuBarSummary.proteinLine(grams: snapshot.proteinG ?? 0, targetGrams: snapshot.proteinTargetG))
            ProgressView(value: MenuBarSummary.waterProgress(ml: snapshot.waterMl, goalMl: snapshot.waterGoalMl)) {
                Text("\(Int(snapshot.waterMl.rounded())) of \(Int(snapshot.waterGoalMl.rounded())) ml water")
                    .font(.callout)
            }
        }
    }

    @ViewBuilder
    private func actions(_ snapshot: WidgetSnapshot) -> some View {
        Button {
            _ = try? QuickLog.water(ml: nil, context: context)
            refresh()
        } label: {
            Label("Add a glass of water", systemImage: "drop.fill")
        }
        Button {
            HomeQuickActionCenter.shared.pending = .logFood
            openMainWindow()
        } label: {
            Label("Search foods…", systemImage: "magnifyingglass")
        }
        if !quickFoods.isEmpty {
            Text("Log again").font(.caption).foregroundStyle(Color.secondary)
            ForEach(quickFoods) { food in
                Button {
                    log(food)
                } label: {
                    Label(food.displayName, systemImage: food.isFavorite ? "star.fill" : "clock")
                        .lineLimit(1)
                }
            }
        }
    }

    private func log(_ food: FoodItem) {
        food.log(servings: food.lastServings ?? 1, meal: .current(), on: .now, context: context)
        try? context.save()
        refresh()
    }

    private func refresh() {
        snapshot = profiles.first.flatMap { WidgetSnapshot.current(profile: $0) }
    }

    /// Brings the existing Stride window forward, or opens one if they're all closed.
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("main") == true }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }
}

/// Settings row that turns the menu bar extra on or off.
struct MenuBarSettingsSection: View {
    @AppStorage(MenuBarSummary.enabledKey) private var enabled = true

    var body: some View {
        Section {
            Toggle("Show Stride in the menu bar", isOn: $enabled)
        } header: {
            Text("Menu bar")
        } footer: {
            Text("Shows calories left, protein and water, with quick ways to add water or log a favourite. With the app lock on, it shows nothing private until you open Stride.")
        }
    }
}
#endif
