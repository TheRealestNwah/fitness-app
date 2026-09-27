import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @AppStorage(Appearance.storageKey) private var appearanceRaw = Appearance.system.rawValue

    private var appearance: Appearance { Appearance(rawValue: appearanceRaw) ?? .system }

    var body: some View {
        Group {
            if let profile = profiles.first {
                MainTabView()
                    .environment(profile)
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .task {
            SeedData.seedIfNeeded(context: context)
        }
    }
}

struct MainTabView: View {
    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: Tab = .today
    /// Start of the current day. Today's queries are built from it, so it's refreshed at
    /// midnight and whenever the app comes back to the foreground.
    @State private var today = Date.now.startOfDay

    enum Tab: Hashable {
        case today, food, weight, vitals, plan
    }

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(day: today, selectTab: { selection = $0 })
                .id(today)
                .tabItem { Label("Today", systemImage: "sun.horizon.fill") }
                .tag(Tab.today)

            FoodDiaryView()
                .tabItem { Label("Food", systemImage: "fork.knife") }
                .tag(Tab.food)

            WeightView()
                .tabItem { Label("Weight", systemImage: "scalemass.fill") }
                .tag(Tab.weight)

            VitalsView()
                .tabItem { Label("Vitals", systemImage: "heart.text.square.fill") }
                .tag(Tab.vitals)

            MealPlanView()
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(Tab.plan)
        }
        .onAppear { NotificationManager.sync(with: profile) }
        .task { await refreshHealth() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshToday()
                Task { await refreshHealth() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            // Posted on a background thread.
            Task { @MainActor in refreshToday() }
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
