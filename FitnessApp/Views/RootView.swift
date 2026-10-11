import SwiftUI
import SwiftData
import UserNotifications

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    /// Oldest first, so if iCloud briefly holds two profiles every device shows the same one.
    @Query(sort: \UserProfile.startDate) private var profiles: [UserProfile]
    @AppStorage(Appearance.storageKey) private var appearanceRaw = Appearance.system.rawValue
    @State private var isResetting = false

    private var appearance: Appearance { Appearance(rawValue: appearanceRaw) ?? .system }

    var body: some View {
        Group {
            if let failure = CloudSync.openFailure {
                StoreRecoveryView(failure: failure)
            } else if isResetting {
                // Swapping the tabs out first means nothing on screen still reads the profile being deleted.
                ResetProgressView()
                    .task { await resetAllData() }
            } else if let profile = profiles.first {
                MainTabView()
                    .environment(profile)
                    .environment(\.resetAllData, ResetAllDataAction { isResetting = true })
            } else {
                OnboardingView()
            }
        }
        // Set the windows' style rather than using preferredColorScheme: that doesn't reach a sheet
        // that's already open (Settings, where the choice is made), and alongside this override it
        // re-applies the previous choice, leaving the sheet one step behind.
        .onChange(of: appearanceRaw, initial: true) { applyToWindows(appearance) }
        .onChange(of: profiles.first?.mealSlotsJSON, initial: true) { MealSlots.shared.apply(json: profiles.first?.mealSlotsJSON ?? "") }
        .task {
            SeedData.seedIfNeeded(context: context)
            if CloudSync.isActive { SyncDeduplicator.run(context: context) }
        }
        .onChange(of: scenePhase) { _, phase in
            // Copies from another device arrive while the app runs, so check again on return.
            if phase == .active, CloudSync.isActive { SyncDeduplicator.run(context: context) }
        }
    }

    private func applyToWindows(_ appearance: Appearance) {
        #if os(macOS)
        NSApp.appearance = appearance == .system ? nil : NSAppearance(named: appearance == .dark ? .darkAqua : .aqua)
        #else
        let style: UIUserInterfaceStyle = switch appearance {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows { window.overrideUserInterfaceStyle = style }
        }
        #endif
    }

    private func resetAllData() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        SpotlightIndex.removeAll()
        #if os(iOS)
        UIApplication.shared.shortcutItems = []
        #endif
        // Let the Settings sheet finish dismissing and keep the progress visible long enough to read.
        try? await Task.sleep(for: .milliseconds(600))
        DemoData.wipe(context: context)
        SeedData.seedIfNeeded(context: context)
        try? context.save()
        isResetting = false
    }
}

struct ResetProgressView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Deleting your data…")
                .font(.headline)
            Text("You'll be taken to setup when it's done.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Shown instead of the app when the data store couldn't be opened (for example a failed
/// migration), so the app explains what happened rather than crashing on every launch.
struct StoreRecoveryView: View {
    let failure: String

    @State private var confirming = false
    @State private var movedAside = false
    @State private var moveError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Stride couldn't open your data", systemImage: "exclamationmark.triangle.fill")
                    .font(.title2.bold())
                    .foregroundStyle(Color.primary)
                if movedAside {
                    Text("Done. Your old data is kept on this device. Close Stride completely and open it again to start fresh, then restore a backup from Settings › Data if you have one.")
                } else {
                    Text("Nothing has been deleted. Updating Stride may fix this, so check the App Store first.")
                    Text("If it keeps happening, you can start fresh. Stride keeps a copy of the old data on this device, and you can restore a backup file afterwards from Settings › Data.")
                    Button("Start Fresh…") { confirming = true }
                        .buttonStyle(.borderedProminent)
                }
                if let moveError {
                    Text(moveError)
                        .foregroundStyle(.red)
                }
                DisclosureGroup("Details") {
                    Text(failure)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("Start fresh?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Start Fresh", role: .destructive, action: moveAside)
        } message: {
            Text("Stride will set the current data aside and start with an empty diary next time it opens.")
        }
    }

    private func moveAside() {
        guard let url = CloudSync.storeURL else {
            moveError = String(localized: "Couldn't find the data file.")
            return
        }
        do {
            try CloudSync.moveAside(storeAt: url, stamp: String(Int(Date.now.timeIntervalSince1970)))
            movedAside = true
            moveError = nil
        } catch {
            moveError = String(localized: "Couldn't set the data aside: \(error.localizedDescription)")
        }
    }
}

/// Lets Settings ask the root view to wipe everything and return to onboarding.
struct ResetAllDataAction {
    var action: () -> Void = {}
    func callAsFunction() { action() }
}

private struct ResetAllDataKey: EnvironmentKey {
    static let defaultValue = ResetAllDataAction()
}

extension EnvironmentValues {
    var resetAllData: ResetAllDataAction {
        get { self[ResetAllDataKey.self] }
        set { self[ResetAllDataKey.self] = newValue }
    }
}

struct MainTabView: View {
    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.strideSizeClass) private var sizeClass
    /// Per window, and restored when the app relaunches.
    @SceneStorage("section") private var selection: Tab = .today
    @State private var undoCenter = UndoCenter()
    @Environment(\.undoManager) private var undoManager
    @State private var columns: NavigationSplitViewVisibility = .all
    /// Settings is showing in the detail column (sidebar layout only).
    @SceneStorage("showsSettings") private var showsSettings = false
    @State private var quickActions = HomeQuickActionCenter.shared
    @State private var quickSheet: QuickSheet?
    @Environment(\.isAppLocked) private var isAppLocked
    /// Start of the current day. Today's queries are built from it, so it's refreshed at
    /// midnight and whenever the app comes back to the foreground.
    @State private var today = Date.now.startOfDay

    enum Tab: String, Hashable, CaseIterable {
        case today, food, weight, vitals, plan

        var title: String {
            switch self {
            case .today: String(localized: "Today")
            case .food: String(localized: "Food")
            case .weight: String(localized: "Weight")
            case .vitals: String(localized: "Vitals")
            case .plan: String(localized: "Plan")
            }
        }

        var systemImage: String {
            switch self {
            case .today: "sun.horizon.fill"
            case .food: "fork.knife"
            case .weight: "scalemass.fill"
            case .vitals: "heart.text.square.fill"
            case .plan: "calendar"
            }
        }
    }

    /// A row in the sidebar: one of the sections, or Settings below them.
    enum SidebarItem: Hashable {
        case section(Tab)
        case settings
    }

    private var usesSidebar: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    private var sidebarSelection: Binding<SidebarItem?> {
        Binding {
            showsSettings ? .settings : .section(selection)
        } set: { item in
            switch item {
            case .section(let tab):
                selection = tab
                showsSettings = false
            case .settings:
                showsSettings = true
            case nil:
                break
            }
        }
    }

    /// Sheets opened from a Home Screen quick action.
    enum QuickSheet: Identifiable {
        case food, weight, settings
        var id: Self { self }
    }

    @ViewBuilder
    private func screen(_ tab: Tab) -> some View {
        switch tab {
        case .today:
            DashboardView(day: today, selectTab: select,
                          openSettings: usesSidebar ? { showsSettings = true } : nil)
                .id(today)
        case .food: FoodDiaryView()
        case .weight: WeightView()
        case .vitals: VitalsView()
        case .plan: MealPlanView()
        }
    }

    var body: some View {
        Group {
            if usesSidebar {
                // iPad and wide windows: a sidebar instead of the tab bar.
                NavigationSplitView(columnVisibility: $columns) {
                    List(selection: sidebarSelection) {
                        ForEach(Tab.allCases, id: \.self) { tab in
                            Label(tab.title, systemImage: tab.systemImage)
                                .accessibilityIdentifier("sidebar-\(tab.title)")
                                .tag(SidebarItem.section(tab))
                        }
                        Section {
                            Label("Settings", systemImage: "gearshape")
                                .accessibilityIdentifier("sidebar-Settings")
                                .tag(SidebarItem.settings)
                        }
                    }
                    .navigationTitle("Stride")
                    .navigationSplitViewColumnWidth(min: 170, ideal: 210, max: 280)
                } detail: {
                    if showsSettings {
                        SettingsView(isSheet: false)
                    } else {
                        screen(selection)
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .overlay(alignment: .bottom) { undoToast }
            } else {
                TabView(selection: $selection) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        screen(tab)
                            // Inside each tab, so the toast sits above the tab bar whatever its height.
                            .overlay(alignment: .bottom) { undoToast }
                            .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                            .tag(tab)
                    }
                }
            }
        }
        .environment(undoCenter)
        .spotlightSupport()
        .animation(.snappy, value: undoCenter.toast)
        .strideSheet(item: $quickSheet) { sheet in
            switch sheet {
            case .food: FoodSearchView(date: Date.now.startOfDay, mealType: MealType.current())
            case .weight: AddWeightSheet()
            case .settings: SettingsView()
            }
        }
        .focusedSceneValue(\.sceneActions, sceneActions)
        .onAppear { undoCenter.undoManager = undoManager }
        .onChange(of: undoManager) { _, manager in undoCenter.undoManager = manager }
        .onChange(of: quickActions.pending, initial: true) { performQuickAction() }
        .onChange(of: isAppLocked) { performQuickAction() }
        .onAppear {
            NotificationManager.sync(with: profile)
            HomeQuickActionCenter.publish(context: context)
        }
        .task { await refreshHealth() }
        .task { await PhoneWorkoutRecovery.run() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { BackgroundRefresh.schedule() }
            if phase == .active {
                refreshToday()
                if let context = profile.modelContext {
                    WidgetWaterQueue.drain(into: context)
                    FastingActivityManager.sync(context: context)
                }
                NotificationManager.sync(with: profile)
                WidgetSnapshot.publish(profile: profile)
                HomeQuickActionCenter.publish(context: context)
                Task { await refreshHealth() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            // Posted on a background thread.
            Task { @MainActor in
                refreshToday()
                NotificationManager.sync(with: profile)
            }
        }
        // Today's reminders depend on what's logged, so replan after saves. A burst of saves, or the
        // same save seen by several windows, is handled once.
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            Task { @MainActor in
                SaveFollowUp.shared.schedule {
                    NotificationManager.sync(with: profile)
                    WidgetSnapshot.publish(profile: profile)
                    HomeQuickActionCenter.publish(context: context)
                }
            }
        }
    }

    private var undoToast: some View {
        UndoToastView()
            .environment(undoCenter)
            .padding(.bottom, 16)
    }

    /// For the menu bar and keyboard shortcuts.
    private var sceneActions: SceneActions {
        SceneActions(select: select,
                     logFood: { quickSheet = .food },
                     logWeight: { quickSheet = .weight },
                     logWater: { _ = try? QuickLog.water(ml: nil, context: context) },
                     openSettings: {
                         if usesSidebar { showsSettings = true } else { quickSheet = .settings }
                     })
    }

    private func select(_ tab: Tab) {
        selection = tab
        showsSettings = false
    }

    /// Runs the Home Screen quick action the app was opened with, once the app is unlocked.
    private func performQuickAction() {
        guard !isAppLocked, let action = quickActions.pending else { return }
        quickActions.pending = nil
        select(.today)
        switch action {
        case .logFood: quickSheet = .food
        case .logWeight: quickSheet = .weight
        case .logWater: _ = try? QuickLog.water(ml: nil, context: context)
        case .toggleFast: _ = try? QuickLog.toggleFast(context: context)
        }
    }

    private func refreshToday() {
        let start = Date.now.startOfDay
        if start != today { today = start }
    }

    private func refreshHealth() async {
        guard HealthSettings.isEnabled else { return }
        await HealthKitManager.shared.requestNewTypesIfNeeded()
        await HealthKitManager.shared.refreshToday()
        _ = await HealthKitManager.shared.importIfDue(into: context)
    }
}
