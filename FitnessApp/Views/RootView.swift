import SwiftUI
import SwiftData
import UserNotifications

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @AppStorage(Appearance.storageKey) private var appearanceRaw = Appearance.system.rawValue
    @State private var isResetting = false

    private var appearance: Appearance { Appearance(rawValue: appearanceRaw) ?? .system }

    var body: some View {
        Group {
            if isResetting {
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
        .preferredColorScheme(appearance.colorScheme)
        .task {
            SeedData.seedIfNeeded(context: context)
        }
    }

    private func resetAllData() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        SpotlightIndex.removeAll()
        UIApplication.shared.shortcutItems = []
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
    @Environment(\.horizontalSizeClass) private var sizeClass
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
                          openSettings: sizeClass == .regular ? { showsSettings = true } : nil)
                .id(today)
        case .food: FoodDiaryView()
        case .weight: WeightView()
        case .vitals: VitalsView()
        case .plan: MealPlanView()
        }
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
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
                } detail: {
                    if showsSettings {
                        SettingsView(isSheet: false)
                    } else {
                        screen(selection)
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                TabView(selection: $selection) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        screen(tab)
                            .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                            .tag(tab)
                    }
                }
            }
        }
        .environment(undoCenter)
        .spotlightSupport()
        .overlay(alignment: .bottom) {
            UndoToastView()
                .environment(undoCenter)
                .padding(.bottom, sizeClass == .regular ? 16 : 58)   // clear of the tab bar
        }
        .animation(.snappy, value: undoCenter.toast)
        .sheet(item: $quickSheet) { sheet in
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
        // Today's reminders depend on what's logged, so replan after every save.
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            Task { @MainActor in
                NotificationManager.sync(with: profile)
                WidgetSnapshot.publish(profile: profile)
                HomeQuickActionCenter.publish(context: context)
            }
        }
    }

    /// For the menu bar and keyboard shortcuts.
    private var sceneActions: SceneActions {
        SceneActions(select: select,
                     logFood: { quickSheet = .food },
                     logWeight: { quickSheet = .weight },
                     logWater: { _ = try? QuickLog.water(ml: nil, context: context) },
                     openSettings: {
                         if sizeClass == .regular { showsSettings = true } else { quickSheet = .settings }
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
        await HealthKitManager.shared.refreshToday()
        _ = await HealthKitManager.shared.importIfDue(into: context)
    }
}
