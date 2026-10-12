import Foundation

/// What each USDA key allows, in plain words, for Settings, setup and search errors.
///
/// The numbers come from USDA's `X-RateLimit-Limit` header: its shared demo key allows 10 searches an
/// hour, and its API guide gives a free personal key at least 1,000 an hour.
extension FoodDataCentralClient.KeySource {
    static let demoSearchesPerHour = 10
    static let personalSearchesPerHour = "1,000"

    /// The status shown beside "Using" in Settings.
    var label: String {
        switch self {
        case .personal: return "Your own USDA key"
        case .stride: return "Stride's USDA key"
        case .shared: return "Shared demo key"
        }
    }

    /// What this key allows, and when a personal key is worth adding.
    var explanation: String {
        switch self {
        case .personal:
            return "Searches use your own USDA key, which allows at least \(Self.personalSearchesPerHour) searches an hour."
        case .stride:
            return "Stride includes its own USDA key, so searching works without any setup. Other people use it too, so it can run out at busy times. A free key of your own allows at least \(Self.personalSearchesPerHour) searches an hour."
        case .shared:
            return "This build has no USDA key of its own, so it uses USDA's shared demo key, which allows only about \(Self.demoSearchesPerHour) searches an hour. A free key of your own allows at least \(Self.personalSearchesPerHour) an hour."
        }
    }

    /// Shown in the results when USDA says the limit is used up.
    var rateLimitMessage: String {
        switch self {
        case .personal:
            return "You've used up the hourly limit for your USDA key. Searches work again within the hour."
        case .stride:
            return "USDA search is busy right now. A free USDA key of your own in Settings gives you your own allowance."
        case .shared:
            return "You've reached the shared demo key's limit of about \(Self.demoSearchesPerHour) searches an hour. A free USDA key of your own in Settings raises that to at least \(Self.personalSearchesPerHour) an hour."
        }
    }

    /// Shown in the results when USDA turns the key down.
    var rejectedMessage: String {
        switch self {
        case .personal: return "USDA rejected your key. Check it in Settings."
        case .stride, .shared: return "USDA rejected the key this build uses. You can add a free key of your own in Settings."
        }
    }
}
