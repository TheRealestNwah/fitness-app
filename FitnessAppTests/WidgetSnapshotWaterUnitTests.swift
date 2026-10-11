import XCTest
@testable import FitnessApp

final class WidgetSnapshotWaterUnitTests: XCTestCase {
    private func snapshot(_ system: UnitSystem) -> WidgetSnapshot {
        let profile = UserProfile(name: "Sam", sex: .female, birthDate: Date(timeIntervalSince1970: 0), heightCm: 168,
                                  startWeightKg: 80, goalWeightKg: 70, activityLevel: .light, weeklyLossKg: 0.5,
                                  unitSystem: system)
        return WidgetSnapshot.make(profile: profile, food: [], water: [], latestWeightKg: nil, logDates: [])
    }

    func testSnapshotCarriesTheVolumeUnit() {
        XCTAssertEqual(snapshot(.metric).waterUnit, "ml")
        XCTAssertEqual(snapshot(.imperial).waterUnit, "fl oz")
    }

    func testSnapshotWithoutAUnitStillDecodes() throws {
        let data = try JSONEncoder().encode(snapshot(.imperial))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["waterUnit"] = nil
        let old = try JSONSerialization.data(withJSONObject: json)
        XCTAssertNil(try JSONDecoder().decode(WidgetSnapshot.self, from: old).waterUnit)
    }
}
