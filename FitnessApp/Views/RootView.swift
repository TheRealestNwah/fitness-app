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
    @State private var selection: Tab = .today

    enum Tab: Hashable {
        case today, food, weight, vitals, plan
    }

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(selectTab: { selection = $0 })
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
    }
}
