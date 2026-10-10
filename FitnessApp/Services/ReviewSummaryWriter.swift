import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Settings and runtime support for the AI-written weekly summary.
enum ReviewSummarySettings {
    static let enabledKey = "aiReviewSummaryEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }
}

/// The pure parts of the weekly summary: what the model is told and how its answer is checked.
/// Only the numbers `WeeklyReviewCalculator` already produced go in; no diary entries are sent
/// anywhere, and the model runs on the device.
enum ReviewSummaryPrompt {
    static let instructions = """
        You write a short weekly check-in for someone using a weight-loss app. Use a warm, encouraging, \
        plain-language tone. Write 3 to 5 sentences: say what went well, then suggest one small thing to try next \
        week. Use only the facts you are given and never invent numbers. Do not give medical advice, do not \
        diagnose anything, and do not mention medication, supplements or health conditions. Never shame, blame or \
        scold, and never call food good or bad. Do not use lists, headings or emoji.
        """

    /// The week as plain facts. Missing data is said to be missing so the model doesn't guess.
    static func facts(for review: WeeklyReview, units: Units) -> String {
        var lines = ["Days with something logged: \(review.daysLogged) of 7."]
        if let average = review.averageIntake {
            lines.append("Average intake on logged days: \(Int(average.rounded())) kcal against a budget of \(review.budget) kcal.")
        } else {
            lines.append("No food was logged, so there is no intake average.")
        }
        if let change = review.weightChangeKg {
            let planned = units.weightString(kg: -review.plannedWeeklyLossKg, signed: true)
            lines.append("Average weight change from the week before: \(units.weightString(kg: change, signed: true)) (the plan is \(planned) a week).")
        } else {
            lines.append("There are not enough weigh-ins to compare this week with the last.")
        }
        if review.completedFasts > 0 {
            lines.append("Fasts completed: \(review.completedFasts).")
        }
        lines.append("The app's own headline: \(review.headline)")
        lines.append("The app's own suggestion: \(review.suggestion)")
        return lines.joined(separator: "\n")
    }

    /// Words that would make a summary medical or shaming; an answer containing one is dropped.
    static let blocked: [String] = [
        "diagnos", "disease", "disorder", "prescri", "medication", "supplement", "doctor", "medical",
        "eating disorder", "anorex", "bulimi", "starv", "purge",
        "lazy", "failure", "failed", "pathetic", "disgust", "guilt", "ashamed", "shame", "cheat", "punish",
        "bad food", "good food", "junk", "sin ",
    ]

    static let maximumLength = 700

    /// Trims the model's answer; nil when it is empty, too long, wrong in shape or contains blocked wording.
    static func accepted(_ text: String) -> String? {
        let cleaned = text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= maximumLength else { return nil }
        let lower = cleaned.lowercased()
        if blocked.contains(where: { lower.contains($0) }) { return nil }
        let sentences = sentenceCount(cleaned)
        guard (2...7).contains(sentences) else { return nil }
        // A list or heading means the model ignored the format.
        if cleaned.contains("\n- ") || cleaned.contains("\n• ") || cleaned.hasPrefix("- ") { return nil }
        return cleaned
    }

    static func sentenceCount(_ text: String) -> Int {
        text.split(whereSeparator: { ".!?".contains($0) })
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }
}

/// Remembers the last summary so it isn't regenerated every time Today appears.
enum ReviewSummaryCache {
    private static let textKey = "aiReviewSummaryText"
    private static let factsKey = "aiReviewSummaryFacts"

    static func cached(for facts: String, defaults: UserDefaults = .standard) -> String? {
        guard defaults.string(forKey: factsKey) == facts else { return nil }
        return defaults.string(forKey: textKey)
    }

    static func store(_ text: String, for facts: String, defaults: UserDefaults = .standard) {
        defaults.set(text, forKey: textKey)
        defaults.set(facts, forKey: factsKey)
    }
}

/// Writes the weekly summary with Apple's on-device model, where it exists.
enum ReviewSummaryWriter {
    /// True on iOS 26 / macOS 26 with Apple Intelligence ready; everywhere else the card keeps its fixed tips.
    static var isSupported: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return OnDeviceSummary.isAvailable }
        #endif
        return false
    }

    /// A summary for the review, or nil when the model is unavailable or its answer isn't acceptable.
    static func summary(for review: WeeklyReview, units: Units) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return await OnDeviceSummary.write(facts: ReviewSummaryPrompt.facts(for: review, units: units))
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
private enum OnDeviceSummary {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func write(facts: String) async -> String? {
        guard isAvailable else { return nil }
        let session = LanguageModelSession(instructions: ReviewSummaryPrompt.instructions)
        do {
            let response = try await session.respond(to: facts, options: GenerationOptions(temperature: 0.6))
            return ReviewSummaryPrompt.accepted(response.content)
        } catch {
            return nil
        }
    }
}
#endif
