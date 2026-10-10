import Foundation
import Observation

/// "Hide numbers" mode: calorie and weight numbers are replaced with dots, for people who want a break
/// from them. It's switched on by hand in Settings or by a Focus filter, and either one is enough.
/// Views that format through `Energy` or `Units.weightString` pick the change up because this is observable.
@Observable
final class NumberPrivacy: @unchecked Sendable {
    static let shared = NumberPrivacy()

    static let manualKey = "hideNumbers"
    static let focusKey = "hideNumbersFocus"
    static let mask = "•••"

    /// Turned on in Settings.
    var manual: Bool {
        didSet { UserDefaults.standard.set(manual, forKey: Self.manualKey) }
    }

    /// Turned on by a Focus that uses Stride's filter; cleared when that Focus ends.
    var focus: Bool {
        didSet { UserDefaults.standard.set(focus, forKey: Self.focusKey) }
    }

    var isOn: Bool { manual || focus }

    private init() {
        manual = UserDefaults.standard.bool(forKey: Self.manualKey)
        focus = UserDefaults.standard.bool(forKey: Self.focusKey)
    }

    /// `text`, or dots while numbers are hidden.
    static func hide(_ text: String) -> String {
        shared.isOn ? mask : text
    }
}
