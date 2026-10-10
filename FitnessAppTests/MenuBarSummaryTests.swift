import XCTest
@testable import FitnessApp

final class MenuBarSummaryTests: XCTestCase {
    private func food(_ favourite: Bool, uses: Int, daysAgo: Int?) -> MenuBarSummary.Food {
        MenuBarSummary.Food(id: UUID(), isFavorite: favourite, useCount: uses,
                            lastUsed: daysAgo.map { Date(timeIntervalSince1970: 1_000_000 - Double($0) * 86_400) })
    }

    func testCaloriesLineSaysLeftOrOver() {
        UserDefaults.standard.set(EnergyUnit.kcal.rawValue, forKey: EnergyUnit.storageKey)
        XCTAssertEqual(MenuBarSummary.caloriesLine(remainingKcal: 420), "420 kcal left")
        XCTAssertEqual(MenuBarSummary.caloriesLine(remainingKcal: -120), "120 kcal over")
    }

    func testProteinLineWithAndWithoutTarget() {
        XCTAssertEqual(MenuBarSummary.proteinLine(grams: 61.6, targetGrams: 120), "62 of 120 g protein")
        XCTAssertEqual(MenuBarSummary.proteinLine(grams: 61.6, targetGrams: nil), "62 g protein")
        XCTAssertEqual(MenuBarSummary.proteinLine(grams: 10, targetGrams: 0), "10 g protein")
    }

    func testWaterProgressIsClamped() {
        XCTAssertEqual(MenuBarSummary.waterProgress(ml: 500, goalMl: 2000), 0.25, accuracy: 0.001)
        XCTAssertEqual(MenuBarSummary.waterProgress(ml: 3000, goalMl: 2000), 1)
        XCTAssertEqual(MenuBarSummary.waterProgress(ml: 500, goalMl: 0), 0)
    }

    func testFavouritesComeFirstThenRecentFoods() {
        let often = food(true, uses: 9, daysAgo: 5)
        let rarely = food(true, uses: 2, daysAgo: 1)
        let recent = food(false, uses: 1, daysAgo: 0)
        let older = food(false, uses: 4, daysAgo: 3)
        let ids = MenuBarSummary.quickFoods([older, recent, rarely, often])
        XCTAssertEqual(ids, [often.id, rarely.id, recent.id, older.id])
    }

    func testUnusedNonFavouritesAreLeftOutAndTheListIsCapped() {
        let unused = food(false, uses: 0, daysAgo: nil)
        let many = (0..<10).map { food(true, uses: $0, daysAgo: $0) }
        XCTAssertFalse(MenuBarSummary.quickFoods([unused] + many).contains(unused.id))
        XCTAssertEqual(MenuBarSummary.quickFoods(many).count, MenuBarSummary.foodLimit)
        XCTAssertEqual(MenuBarSummary.quickFoods(many, limit: 2).count, 2)
    }

    #if os(macOS)
    func testSettingsSearchFindsTheMenuBarToggleOnMac() {
        XCTAssertEqual(SettingsSearch.search("menu bar").first?.page, .privacy)
    }
    #endif
}
