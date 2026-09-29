import SwiftData
import XCTest
@testable import FitnessApp

@MainActor
final class NotificationManagerTests: XCTestCase {
    // Held so the context stays valid: a ModelContext doesn't keep its container alive.
    private var container: ModelContainer!
    private var profile: UserProfile!

    override func setUp() async throws {
        container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        profile = UserProfile(name: "Sam", sex: .female, birthDate: Date(timeIntervalSince1970: 0), heightCm: 168,
                              startWeightKg: 80, goalWeightKg: 70, activityLevel: .light, weeklyLossKg: 0.5,
                              unitSystem: .metric)
        container.mainContext.insert(profile)
        profile.weighInReminderEnabled = false
        profile.mealReminderEnabled = false
        profile.waterReminderEnabled = false
        profile.proteinReminderEnabled = false
        profile.dayCloseReminderHour = nil
    }

    func testNoRemindersNeedNoPermission() {
        XCTAssertFalse(NotificationManager.anyReminderEnabled(profile))
    }

    func testProteinCheckAloneNeedsPermission() {
        profile.proteinReminderEnabled = true
        XCTAssertTrue(NotificationManager.anyReminderEnabled(profile))
    }

    func testEveningCheckInAloneNeedsPermission() {
        profile.dayCloseReminderHour = 20
        XCTAssertTrue(NotificationManager.anyReminderEnabled(profile))
    }

    func testEachOtherReminderNeedsPermission() {
        let keyPaths: [ReferenceWritableKeyPath<UserProfile, Bool>] = [
            \.weighInReminderEnabled, \.mealReminderEnabled, \.waterReminderEnabled,
        ]
        for keyPath in keyPaths {
            profile[keyPath: keyPath] = true
            XCTAssertTrue(NotificationManager.anyReminderEnabled(profile))
            profile[keyPath: keyPath] = false
        }
    }
}
