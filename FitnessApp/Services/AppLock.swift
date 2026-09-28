import Foundation
import LocalAuthentication
import SwiftUI

/// Optional Face ID / Touch ID / passcode lock when the app opens or comes back.
enum AppLock {
    static let enabledKey = "appLockEnabled"
    static let graceKey = "appLockGrace"

    enum Grace: Int, CaseIterable, Identifiable {
        case immediately = 0
        case oneMinute = 60
        case fiveMinutes = 300

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .immediately: String(localized: "Immediately")
            case .oneMinute: String(localized: "After 1 minute")
            case .fiveMinutes: String(localized: "After 5 minutes")
            }
        }
    }

    /// Locks on launch (no background time recorded) and after the grace period away.
    static func shouldLock(enabled: Bool, backgroundedAt: Date?, now: Date, grace: Grace) -> Bool {
        guard enabled else { return false }
        guard let backgroundedAt else { return true }
        return now.timeIntervalSince(backgroundedAt) >= TimeInterval(grace.rawValue)
    }

    /// "Face ID", "Touch ID", "Optic ID" or "Passcode", for labels.
    static var methodName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return String(localized: "Face ID")
        case .touchID: return String(localized: "Touch ID")
        case .opticID: return String(localized: "Optic ID")
        default: return String(localized: "Passcode")
        }
    }

    /// Biometrics with the device passcode as a fallback.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

/// Covers the app while locked, and blurs it in the app switcher when the lock is on.
struct AppLockGate: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppLock.enabledKey) private var enabled = false
    @AppStorage(AppLock.graceKey) private var graceRaw = AppLock.Grace.immediately.rawValue
    @State private var locked = UserDefaults.standard.bool(forKey: AppLock.enabledKey)
    @State private var backgroundedAt: Date?
    @State private var authenticating = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled && (locked || scenePhase != .active) {
                    LockCover(locked: locked, unlock: unlock)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: locked)
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    if !locked { backgroundedAt = .now }
                case .active:
                    let grace = AppLock.Grace(rawValue: graceRaw) ?? .immediately
                    if AppLock.shouldLock(enabled: enabled, backgroundedAt: backgroundedAt, now: .now, grace: grace) {
                        locked = true
                    }
                    if locked { unlock() }
                default:
                    break
                }
            }
            .onChange(of: enabled) { _, on in
                if !on { locked = false }
            }
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
            authenticating = false
        }
    }
}

private struct LockCover: View {
    var locked: Bool
    var unlock: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            if locked {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.accentColor)
                    Text("Stride is locked")
                        .font(.headline)
                    Button("Unlock with \(AppLock.methodName)", action: unlock)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

extension View {
    func appLockGate() -> some View { modifier(AppLockGate()) }
}

/// Settings rows for the lock.
struct AppLockSection: View {
    @AppStorage(AppLock.enabledKey) private var enabled = false
    @AppStorage(AppLock.graceKey) private var graceRaw = AppLock.Grace.immediately.rawValue
    @State private var failed = false

    var body: some View {
        Section {
            Toggle("Require \(AppLock.methodName)", isOn: Binding(
                get: { enabled },
                set: { on in
                    // Turning it on or off needs the owner, so a borrowed phone can't do either.
                    Task { @MainActor in
                        if await AppLock.authenticate(reason: on ? "Turn on the app lock." : "Turn off the app lock.") {
                            enabled = on
                        } else {
                            failed = true
                        }
                    }
                }))
            if enabled {
                Picker("Lock", selection: $graceRaw) {
                    ForEach(AppLock.Grace.allCases) { Text($0.label).tag($0.rawValue) }
                }
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text(failed ? "Couldn't confirm it's you. Set a passcode on this device to use the lock."
                        : "Asks for \(AppLock.methodName) or your passcode when Stride opens, and hides it in the app switcher.")
        }
    }
}
