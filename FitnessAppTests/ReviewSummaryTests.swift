import XCTest
@testable import FitnessApp

final class ReviewSummaryTests: XCTestCase {
    private let units = Units(system: .metric)

    private func review(logged: Int = 6, intake: Double? = 1850, change: Double? = -0.4, fasts: Int = 0) -> WeeklyReview {
        WeeklyReview(daysLogged: logged, averageIntake: intake, budget: 1900, weightChangeKg: change,
                     plannedWeeklyLossKg: 0.5, headline: "Right on track.", suggestion: "Keep logging dinner.",
                     completedFasts: fasts)
    }

    func testFactsCarryTheReviewNumbers() {
        let facts = ReviewSummaryPrompt.facts(for: review(fasts: 2), units: units)
        XCTAssertTrue(facts.contains("6 of 7"))
        XCTAssertTrue(facts.contains("1850 kcal"))
        XCTAssertTrue(facts.contains("1900 kcal"))
        XCTAssertTrue(facts.contains("Fasts completed: 2"))
        XCTAssertTrue(facts.contains("Right on track."))
        XCTAssertTrue(facts.contains("Keep logging dinner."))
    }

    func testFactsSayWhenDataIsMissing() {
        let facts = ReviewSummaryPrompt.facts(for: review(logged: 0, intake: nil, change: nil), units: units)
        XCTAssertTrue(facts.contains("No food was logged"))
        XCTAssertTrue(facts.contains("not enough weigh-ins"))
        XCTAssertFalse(facts.contains("Fasts completed"))
    }

    func testFactsNeverIncludeDiaryDetail() {
        // The review only holds totals, so a food name can't reach the prompt.
        let facts = ReviewSummaryPrompt.facts(for: review(), units: units)
        XCTAssertFalse(facts.lowercased().contains("pizza"))
        XCTAssertEqual(facts.split(separator: "\n").count, 5)
    }

    func testInstructionsSetTheGuardrails() {
        let text = ReviewSummaryPrompt.instructions.lowercased()
        for phrase in ["3 to 5 sentences", "do not give medical advice", "never shame", "never invent numbers", "only the facts"] {
            XCTAssertTrue(text.contains(phrase), "Missing: \(phrase)")
        }
    }

    func testAcceptsAFriendlyShortSummary() {
        let text = "You logged six days this week and stayed close to your budget. Your weight is moving the way you planned. Next week, try logging dinner right after you eat."
        XCTAssertEqual(ReviewSummaryPrompt.accepted("  \(text) \n"), text)
    }

    func testStripsMarkdownEmphasis() {
        let accepted = ReviewSummaryPrompt.accepted("**Nice week.** You logged six days. Keep going.")
        XCTAssertEqual(accepted, "Nice week. You logged six days. Keep going.")
    }

    func testRejectsMedicalAndShamingWording() {
        for bad in ["You should ask your doctor about this. You did fine otherwise.",
                    "That was a lazy week. Try harder next time.",
                    "You cheated on Friday. Do better.",
                    "Your medication may explain this. Keep going.",
                    "Pizza is bad food. Skip it next week."] {
            XCTAssertNil(ReviewSummaryPrompt.accepted(bad), bad)
        }
    }

    func testRejectsEmptyTooLongAndWrongShape() {
        XCTAssertNil(ReviewSummaryPrompt.accepted("   "))
        XCTAssertNil(ReviewSummaryPrompt.accepted("One sentence only."))
        XCTAssertNil(ReviewSummaryPrompt.accepted(String(repeating: "Good week. ", count: 100)))
        XCTAssertNil(ReviewSummaryPrompt.accepted("Great week.\n- Logged six days\n- On budget\n- Keep going"))
    }

    func testSentenceCount() {
        XCTAssertEqual(ReviewSummaryPrompt.sentenceCount("One. Two! Three?"), 3)
        XCTAssertEqual(ReviewSummaryPrompt.sentenceCount(""), 0)
    }

    func testCacheReturnsTheSummaryOnlyForTheSameFacts() {
        let suite = "ReviewSummaryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertNil(ReviewSummaryCache.cached(for: "a", defaults: defaults))
        ReviewSummaryCache.store("Hello there. Nice week.", for: "a", defaults: defaults)
        XCTAssertEqual(ReviewSummaryCache.cached(for: "a", defaults: defaults), "Hello there. Nice week.")
        XCTAssertNil(ReviewSummaryCache.cached(for: "b", defaults: defaults))
    }

    func testEnabledByDefault() {
        let key = ReviewSummarySettings.enabledKey
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertTrue(ReviewSummarySettings.isEnabled)
        UserDefaults.standard.set(false, forKey: key)
        XCTAssertFalse(ReviewSummarySettings.isEnabled)
    }
}
