import SwiftUI
import TipKit

/// One-time pointers to features that are easy to miss. Each is invalidated once the
/// feature is used, and TipKit remembers a dismissed tip across launches.
struct BarcodeTip: Tip {
    var title: Text {
        #if os(macOS)
        Text("Look up a barcode")
        #else
        Text("Scan instead of typing")
        #endif
    }
    var message: Text? {
        #if os(macOS)
        Text("Enter the barcode on a package to find its food and nutrition label.")
        #else
        Text("Point the camera at a barcode to find packaged food and its nutrition label.")
        #endif
    }
    var image: Image? { Image(systemName: "barcode.viewfinder") }
}

struct CopyYesterdayTip: Tip {
    var title: Text { Text("Same as yesterday?") }
    var message: Text? { Text("Use Copy yesterday's meal, or the ••• menu on any meal, to log it again in one tap.") }
    var image: Image? { Image(systemName: "arrow.uturn.backward.circle") }
}

struct AdaptiveTargetTip: Tip {
    var title: Text { Text("Your real maintenance is ready") }
    var message: Text? { Text("Measured from what you logged and what the scale did. It's usually more accurate than the formula.") }
    var image: Image? { Image(systemName: "chart.line.uptrend.xyaxis") }
}

enum FeatureTips {
    static let resetOnLaunchKey = "resetFeatureTipsOnLaunch"

    /// Call once at launch, before any tip is shown.
    static func configure() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: resetOnLaunchKey) {
            // The datastore can only be reset before TipKit is configured.
            try? Tips.resetDatastore()
            defaults.set(false, forKey: resetOnLaunchKey)
        }
        if DemoData.shouldReset || DemoData.shouldLoadDemo {
            Tips.hideAllTipsForTesting()      // keep UI tests and screenshots clean
        }
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    /// Shows every tip again the next time the app starts.
    static func resetOnNextLaunch() {
        UserDefaults.standard.set(true, forKey: resetOnLaunchKey)
    }
}
