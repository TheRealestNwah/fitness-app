import SwiftUI

/// Lets UI tests put the app in a compact-width window, as in Split View or Slide Over, and
/// switch width mid-session, which a simulator can't be told to do. Only active with the
/// launch arguments `-compactWidth` (start compact) and `-flipWidthAfter <seconds>`.
struct UITestSizeClass: ViewModifier {
    @Environment(\.horizontalSizeClass) private var system
    @State private var override: UserInterfaceSizeClass? = Self.startsCompact ? .compact : nil

    static var arguments: [String] { ProcessInfo.processInfo.arguments }
    static var startsCompact: Bool { arguments.contains("-compactWidth") }
    static var flipAfter: Double? {
        guard let i = arguments.firstIndex(of: "-flipWidthAfter"), i + 1 < arguments.count else { return nil }
        return Double(arguments[i + 1])
    }

    func body(content: Content) -> some View {
        // Always applied, so switching width doesn't change the view's identity.
        content
            .environment(\.horizontalSizeClass, override ?? system)
            .task {
                guard let delay = Self.flipAfter else { return }
                try? await Task.sleep(for: .seconds(delay))
                override = (override ?? system) == .compact ? .regular : .compact
            }
    }
}

extension View {
    func uiTestSizeClass() -> some View { modifier(UITestSizeClass()) }
}
