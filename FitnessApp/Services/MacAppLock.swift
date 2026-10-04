#if os(macOS)
import SwiftUI
import AppKit

/// Removes protected content, including sheets, while locked or inactive.
struct AppLockGate: ViewModifier {
    @AppStorage(AppLock.enabledKey) private var enabled = false
    @AppStorage(AppLock.graceKey) private var graceRaw = AppLock.Grace.immediately.rawValue
    @State private var locked = UserDefaults.standard.bool(forKey: AppLock.enabledKey)
    @State private var backgroundedAt: Date?
    @State private var authenticating = false
    @State private var inactive = false

    func body(content: Content) -> some View {
        ZStack {
            if enabled && (locked || inactive) {
                LockCover(locked: locked && !inactive, unlock: unlock)
            } else {
                content
                    .privacySensitive(enabled)
            }
        }
        .environment(\.isAppLocked, enabled && locked)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            // Authentication itself temporarily deactivates the app.
            guard !authenticating else { return }
            inactive = true
            backgroundedAt = .now
            if enabled && graceRaw == 0 { locked = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            inactive = false
            guard !authenticating else { return }
            if AppLock.shouldLock(enabled: enabled, backgroundedAt: backgroundedAt, now: .now,
                                  grace: AppLock.Grace(rawValue: graceRaw) ?? .immediately) {
                locked = true
            }
            if locked { unlock() }
        }
        .onChange(of: enabled) { _, on in if !on { locked = false } }
        .task { if locked { unlock() } }
    }

    private func unlock() {
        guard !authenticating else { return }
        authenticating = true
        Task { @MainActor in
            if await AppLock.authenticate(reason: "Unlock Stride to see your logs.") {
                locked = false
                backgroundedAt = nil
            }
            inactive = false
            authenticating = false
        }
    }
}
#endif
