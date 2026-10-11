import Foundation

/// Runs app-wide work that follows a save (replanning reminders, the widget snapshot, quick
/// actions) once after saves settle, instead of once per save in every open window.
@MainActor
final class SaveFollowUp {
    static let shared = SaveFollowUp()
    static let delay: Duration = .milliseconds(400)

    private var pending: Task<Void, Never>?

    /// Replaces any work still waiting, so a burst of saves runs the latest work once.
    func schedule(after delay: Duration = SaveFollowUp.delay, _ work: @escaping @MainActor () -> Void) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            work()
        }
    }
}
