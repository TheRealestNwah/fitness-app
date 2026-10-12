import XCTest
import SwiftData
@testable import FitnessApp

final class WeightGoalTests: XCTestCase {
    func testOnlyLosingWeightNeedsAGoalWeight() {
        XCTAssertTrue(WeightGoal.lose.needsGoalWeight)
        XCTAssertFalse(WeightGoal.steady.needsGoalWeight)
        XCTAssertFalse(WeightGoal.track.needsGoalWeight)
    }

    @MainActor
    func testKeepingSteadyTargetsMaintenanceCalories() throws {
        // What onboarding sets up for "Keep my weight steady" and "Just track".
        let container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let profile = UserProfile(name: "", sex: .female, birthDate: Date(timeIntervalSince1970: 0), heightCm: 170,
                                  startWeightKg: 80, goalWeightKg: 80, activityLevel: .light, weeklyLossKg: 0.5,
                                  unitSystem: .metric)
        container.mainContext.insert(profile)
        profile.startMaintenance(atKg: 80)
        let tdee = profile.tdee(currentWeightKg: 80)
        XCTAssertEqual(profile.calorieTarget(currentWeightKg: 80), MaintenanceCalculator.calorieTarget(tdee: tdee, sex: .female))
        XCTAssertGreaterThan(profile.calorieTarget(currentWeightKg: 80),
                             NutritionCalculator.dailyCalorieTarget(tdee: tdee, weeklyLossKg: 0.5, sex: .female))
    }
}
