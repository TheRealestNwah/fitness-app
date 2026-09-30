import XCTest
@testable import FitnessApp

final class RecentFoodsTests: XCTestCase {
    private let today = Calendar.current.startOfDay(for: .now)

    private func line(_ key: String, daysAgo: Int, _ meal: MealType = .breakfast) -> RecentFoods.Line {
        RecentFoods.Line(key: key, date: today.adding(days: -daysAgo).addingTimeInterval(8 * 3600), mealType: meal)
    }

    func testRanksByDaysEatenThenRecency() {
        let history = [line("oats", daysAgo: 1), line("oats", daysAgo: 2), line("oats", daysAgo: 3),
                       line("toast", daysAgo: 1), line("toast", daysAgo: 4),
                       line("eggs", daysAgo: 2), line("yogurt", daysAgo: 5)]
        XCTAssertEqual(RecentFoods.suggestions(history: history, meal: .breakfast, alreadyLogged: []),
                       ["oats", "toast", "eggs", "yogurt"])
    }

    func testTwoLinesOnOneDayCountOnce() {
        let history = [line("coffee", daysAgo: 1), line("coffee", daysAgo: 1), line("banana", daysAgo: 1), line("banana", daysAgo: 2)]
        XCTAssertEqual(RecentFoods.suggestions(history: history, meal: .breakfast, alreadyLogged: []).first, "banana")
    }

    func testOnlyTheSameMealAndNotAlreadyLogged() {
        let history = [line("oats", daysAgo: 1), line("pasta", daysAgo: 1, .dinner), line("toast", daysAgo: 2)]
        XCTAssertEqual(RecentFoods.suggestions(history: history, meal: .breakfast, alreadyLogged: ["oats"]), ["toast"])
    }

    func testLimit() {
        let history = (1...9).map { line("food\($0)", daysAgo: $0) }
        XCTAssertEqual(RecentFoods.suggestions(history: history, meal: .breakfast, alreadyLogged: [], limit: 3),
                       ["food1", "food2", "food3"])
    }

    func testKeyPrefersFoodIDOverName() {
        let id = UUID()
        let entry = FoodLogEntry(date: today, mealType: .lunch, foodName: " Soup ", servings: 1, servingDescription: "",
                                 calories: 100, protein: 1, carbs: 1, fat: 1)
        XCTAssertEqual(entry.recentKey, "soup")
        entry.foodItemID = id
        XCTAssertEqual(entry.recentKey, id.uuidString)
    }
}
