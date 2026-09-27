import XCTest
@testable import FitnessApp

final class WidgetSnapshotTests: XCTestCase {
    func testCountsOnlyToday() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 30, hour: 15))!
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let profile = UserProfile(name: "", sex: .female, birthDate: .now, heightCm: 165, startWeightKg: 70,
                                  goalWeightKg: 62, activityLevel: .light, weeklyLossKg: 0.5, unitSystem: .metric)
        let snapshot = WidgetSnapshot.make(profile: profile,
                                           food: [(now, 500), (now, 300), (yesterday, 900)],
                                           water: [(now, 250), (yesterday, 2000)],
                                           latestWeightKg: 68.4, logDates: [now, yesterday],
                                           now: now, calendar: cal)
        XCTAssertEqual(snapshot.consumedKcal, 800)
        XCTAssertEqual(snapshot.waterMl, 250)
        XCTAssertEqual(snapshot.weightText, "68.4 kg")
        XCTAssertEqual(snapshot.streak, 2)
        XCTAssertEqual(snapshot.remainingKcal, Double(snapshot.targetKcal) - 800)
    }

    func testRoundTripsAsJSON() throws {
        let snapshot = WidgetSnapshot(day: .now, consumedKcal: 1, targetKcal: 2, waterMl: 3, waterGoalMl: 4,
                                      weightText: nil, streak: 5, energyUnit: "kJ")
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(decoded, snapshot)
    }
}
