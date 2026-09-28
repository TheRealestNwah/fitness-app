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
    @State private var selection: Tab = .today
    @State private var undoCenter = UndoCenter()
    @State private var columns: NavigationSplitViewVisibility = .all
    /// Start of the current day. Today's queries are built from it, so it's refreshed at
    /// midnight and whenever the app comes back to the foreground.
    @State private var today = Date.now.startOfDay

    enum Tab: Hashable, CaseIterable {
        case today, food, weight, vitals, plan

        var title: String {
            switch self {
            case .today: "Today"
            case .food: "Food"
            case .weight: "Weight"
            case .vitals: "Vitals"
            case .plan: "Plan"
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

    @ViewBuilder
    private func screen(_ tab: Tab) -> some View {
        switch tab {
        case .today: DashboardView(day: today, selectTab: { selection = $0 }).id(today)
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
                    List(Tab.allCases, id: \.self, selection: Binding<Tab?>(get: { selection },
                                                                           set: { if let tab = $0 { selection = tab } })) { tab in
                        Label(tab.title, systemImage: tab.systemImage)
                            .accessibilityIdentifier("sidebar-\(tab.title)")
                    }
                    .navigationTitle("Stride")
                } detail: {
                    screen(selection)
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
        .overlay(alignment: .bottom) {
            UndoToastView()
                .environment(undoCenter)
                .padding(.bottom, sizeClass == .regular ? 16 : 58)   // clear of the tab bar
        }
        .animation(.snappy, value: undoCenter.toast)
        .onAppear { NotificationManager.sync(with: profile) }
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
            }
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
