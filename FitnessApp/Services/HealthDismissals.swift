import Foundation

/// Apple Health sample ids whose Stride entries were deleted, so later imports don't bring them back.
/// Imports only look back a couple of days past the last one, so a short list is enough.
enum HealthDismissals {
    enum Kind: String {
        case workout, weight
    }

    static let limit = 500

    static func key(_ kind: Kind) -> String { "healthDismissed.\(kind.rawValue)" }

    static func ids(_ kind: Kind, defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: key(kind)) ?? [])
    }

    /// Remembers the ids, keeping the most recent `limit`.
    static func dismiss(_ ids: [String], kind: Kind, defaults: UserDefaults = .standard) {
        guard !ids.isEmpty else { return }
        var list = (defaults.stringArray(forKey: key(kind)) ?? []).filter { !ids.contains($0) }
        list.append(contentsOf: ids)
        defaults.set(Array(list.suffix(limit)), forKey: key(kind))
    }

    /// Forgets the ids again, for when a delete is undone.
    static func restore(_ ids: [String], kind: Kind, defaults: UserDefaults = .standard) {
        guard !ids.isEmpty, let list = defaults.stringArray(forKey: key(kind)) else { return }
        defaults.set(list.filter { !ids.contains($0) }, forKey: key(kind))
    }
}
