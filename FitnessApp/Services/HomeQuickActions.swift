import SwiftUI
import SwiftData
import UIKit

/// The actions offered when the app icon is long-pressed on the Home Screen.
enum HomeQuickAction: String, CaseIterable {
    case logFood = "com.stride.FitnessApp.logFood"
    case logWeight = "com.stride.FitnessApp.logWeight"
    case logWater = "com.stride.FitnessApp.logWater"
    case toggleFast = "com.stride.FitnessApp.toggleFast"

    init?(_ item: UIApplicationShortcutItem) {
        self.init(rawValue: item.type)
    }

    /// The fast action reads Start or End depending on whether one is running.
    func title(fastRunning: Bool) -> String {
        switch self {
        case .logFood: String(localized: "Log food")
        case .logWeight: String(localized: "Weigh in")
        case .logWater: String(localized: "Log water")
        case .toggleFast: fastRunning ? String(localized: "End fast") : String(localized: "Start fast")
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

    static func items(fastRunning: Bool) -> [UIApplicationShortcutItem] {
        allCases.map {
            UIApplicationShortcutItem(type: $0.rawValue, localizedTitle: $0.title(fastRunning: fastRunning),
                                      localizedSubtitle: nil,
                                      icon: UIApplicationShortcutIcon(systemImageName: $0.systemImage))
        }
    }
}

/// Hands a chosen quick action from UIKit to the SwiftUI view that performs it.
@MainActor @Observable
final class HomeQuickActionCenter {
    static let shared = HomeQuickActionCenter()

    var pending: HomeQuickAction?

    /// Refreshes the Home Screen menu. Offered only once setup is done, since every action needs a profile.
    static func publish(context: ModelContext) {
        guard QuickLog.profile(in: context) != nil else {
            UIApplication.shared.shortcutItems = []
            return
        }
        UIApplication.shared.shortcutItems = HomeQuickAction.items(fastRunning: QuickLog.activeFast(context: context) != nil)
    }
}

/// Receives quick actions: at launch through the scene's connection options, and while running
/// through the scene delegate.
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
