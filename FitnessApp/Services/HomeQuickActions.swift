import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The actions offered when the app icon is long-pressed on the Home Screen.
enum HomeQuickAction: String, CaseIterable {
    case logFood = "com.stride.FitnessApp.logFood"
    case logWeight = "com.stride.FitnessApp.logWeight"
    case logWater = "com.stride.FitnessApp.logWater"
    case toggleFast = "com.stride.FitnessApp.toggleFast"

    #if os(iOS)
    init?(_ item: UIApplicationShortcutItem) {
        self.init(rawValue: item.type)
    }
    #endif

    /// The fast action reads Start or End depending on whether one is running.
    func title(fastRunning: Bool) -> String {
        switch self {
        case .logFood: String(localized: "Log food")
        case .logWeight: String(localized: "Weigh in")
        case .logWater: String(localized: "Log water")
        case .toggleFast:
            if fastRunning { String(localized: "End fast") } else { String(localized: "Start fast") }
        }
    }

    var systemImage: String {
        switch self {
        case .logFood: "fork.knife"
        case .logWeight: "scalemass"
        case .logWater: "drop.fill"
        case .toggleFast: "timer"
        }
    }

    #if os(iOS)
    static func items(fastRunning: Bool) -> [UIApplicationShortcutItem] {
        allCases.map {
            UIApplicationShortcutItem(type: $0.rawValue, localizedTitle: $0.title(fastRunning: fastRunning),
                                      localizedSubtitle: nil,
                                      icon: UIApplicationShortcutIcon(systemImageName: $0.systemImage))
        }
    }
    #endif
}

/// Hands a chosen quick action from UIKit to the SwiftUI view that performs it.
@MainActor @Observable
final class HomeQuickActionCenter {
    static let shared = HomeQuickActionCenter()

    var pending: HomeQuickAction?

    /// Refreshes the Home Screen menu. Offered only once setup is done, since every action needs a profile.
    static func publish(context: ModelContext) {
        #if os(iOS)
        guard QuickLog.profile(in: context) != nil else {
            UIApplication.shared.shortcutItems = []
            return
        }
        UIApplication.shared.shortcutItems = HomeQuickAction.items(fastRunning: QuickLog.activeFast(context: context) != nil)
        #endif
    }
}

/// Receives quick actions: at launch through the scene's connection options, and while running
/// through the scene delegate.
#if os(iOS)
final class StrideAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let item = options.shortcutItem, let action = HomeQuickAction(item) {
            MainActor.assumeIsolated { HomeQuickActionCenter.shared.pending = action }
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = StrideSceneDelegate.self
        return configuration
    }
}

final class StrideSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        guard let action = HomeQuickAction(shortcutItem) else { return completionHandler(false) }
        MainActor.assumeIsolated { HomeQuickActionCenter.shared.pending = action }
        completionHandler(true)
    }
}
#endif
