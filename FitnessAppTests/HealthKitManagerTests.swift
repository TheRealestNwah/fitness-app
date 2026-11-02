import SwiftData
import XCTest
@testable import FitnessApp

/// `HealthKitManager` run against `FakeHealthStore`, so the import and mirroring rules are
/// checked without HealthKit.
@MainActor
final class HealthKitManagerTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var container: ModelContainer!
    private var context: ModelContext!
    private var health: FakeHealthStore!
    private var manager: HealthKitManager!
    private let clock = TestClock()
    private var now: Date {
        get { clock.now }
        set { clock.now = newValue }
    }
    private let calendar = Calendar.current

    override func setUp() async throws {
        suiteName = "HealthKitManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.set(true, forKey: HealthSettings.enabledKey)
        container = try ModelContainer(for: AppStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        context = container.mainContext
        health = FakeHealthStore()
        now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12)) ?? .now
        let testClock = clock
        manager = HealthKitManager(store: health, defaults: defaults, now: { testClock.now })
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func daysAgo(_ days: Int, hour: Int = 8) -> Date {
        let day = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(byAdding: .hour, value: hour, to: day) ?? day
    }

    private func reading(_ value: Double, at date: Date, fromThisApp: Bool = false) -> HealthQuantitySample {
        HealthQuantitySample(id: UUID(), date: date, value: value, fromThisApp: fromThisApp)
    }

    private func wait(_ task: Task<Void, Never>?) async {
        if let task { await task.value }
    }

    private func entry(calories: Double = 320) -> FoodLogEntry {
        FoodLogEntry(date: now, mealType: .lunch, foodName: "Soup", servings: 1, servingDescription: "1 bowl",
                     calories: calories, protein: 12, carbs: 30, fat: 9)
    }

    // MARK: Switched off

    func testDoesNothingWhenSyncIsOff() async throws {
        defaults.set(false, forKey: HealthSettings.enabledKey)
        health.totals = [.steps: 4000, .activeEnergy: 300]
        health.readings[.bodyMass] = [reading(80, at: daysAgo(1))]

        await manager.refreshToday()
        let summary = await manager.importIfDue(into: context, force: true)

        XCTAssertEqual(manager.todaySteps, 0)
        XCTAssertNil(summary)
        XCTAssertNil(manager.recordDiaryEntry(entry()))
        XCTAssertNil(manager.removeWater(id: UUID()))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WeightEntry>()), 0)
    }

    func testDoesNothingWithoutAppleHealth() async throws {
        health.isAvailable = false
        health.totals = [.steps: 4000]

        await manager.refreshToday()

        XCTAssertEqual(manager.todaySteps, 0)
        XCTAssertNil(manager.recordDiaryEntry(entry()))
        do {
            try await manager.requestAuthorization()
            XCTFail("Expected an error")
        } catch {
            XCTAssertTrue(error is HealthKitError)
        }
    }

    // MARK: Today's activity

    func testRefreshTodayReadsStepsAndActiveEnergyAndCreditsTheChosenShare() async {
        defaults.set(50, forKey: HealthSettings.creditPercentKey)
        health.totals = [.steps: 6543.4, .activeEnergy: 401]

        await manager.refreshToday()

        XCTAssertEqual(manager.todaySteps, 6543)
        XCTAssertEqual(manager.todayActiveEnergyKcal, 401)
        XCTAssertEqual(manager.activeEnergyCredit, 201)
        XCTAssertEqual(manager.lastRefresh, now)
        XCTAssertNil(manager.lastError)
    }

    func testCreditIsZeroWhenSyncIsTurnedOff() async {
        defaults.set(100, forKey: HealthSettings.creditPercentKey)
        health.totals = [.activeEnergy: 300]
        await manager.refreshToday()
        XCTAssertEqual(manager.activeEnergyCredit, 300)

        defaults.set(false, forKey: HealthSettings.enabledKey)
        XCTAssertEqual(manager.activeEnergyCredit, 0)
    }

    func testRefreshTodayKeepsTheLastValuesAndReportsAnError() async {
        health.totals = [.steps: 3000]
        await manager.refreshToday()
        health.error = FakeHealthStore.Failure()

        await manager.refreshToday()

        XCTAssertEqual(manager.todaySteps, 3000)
        XCTAssertEqual(manager.lastError, "Health said no")
    }

    func testDailyActivityFillsDaysWithNothingAndEndsToday() async {
        let today = calendar.startOfDay(for: now)
        let twoDaysAgo = calendar.startOfDay(for: daysAgo(2))
        health.daily = [.steps: [today: 5000.6, twoDaysAgo: 8000], .activeEnergy: [today: 250]]

        let days = await manager.dailyActivity(days: 3)

        XCTAssertEqual(days.map(\.date), [twoDaysAgo, calendar.startOfDay(for: daysAgo(1)), today])
        XCTAssertEqual(days.map(\.steps), [8000, 0, 5001])
        XCTAssertEqual(days.map(\.activeKcal), [0, 0, 250])
    }

    // MARK: Import

    func testImportAddsNewWeighInsVitalsAndWorkoutsOnce() async throws {
        let dismissed = reading(79, at: daysAgo(3))
        HealthDismissals.dismiss([dismissed.id.uuidString], kind: .weight, defaults: defaults)
        health.readings[.bodyMass] = [reading(80.04, at: daysAgo(2)),
                                      reading(81, at: daysAgo(1), fromThisApp: true),
                                      dismissed]
        health.readings[.restingHeartRate] = [reading(62, at: daysAgo(1, hour: 6)), reading(58.6, at: daysAgo(1, hour: 9))]
        health.sleep = [HealthSleepInterval(start: daysAgo(2, hour: 23), end: daysAgo(1, hour: 6)),
                        // Under an hour: a nap or noise, not a night.
                        HealthSleepInterval(start: daysAgo(0, hour: 1), end: daysAgo(0, hour: 1).addingTimeInterval(1200))]
        health.workoutSamples = [HealthWorkoutSample(id: UUID(), date: daysAgo(1, hour: 18), activity: "Running",
                                                     duration: 1800, activeCalories: 310.4)]

        let summary = try await manager.importSamples(since: daysAgo(7), into: context)

        XCTAssertEqual(summary, HealthImportSummary(weighIns: 1, restingHeartRateDays: 1, sleepNights: 1, workouts: 1))
        let weights = try context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(weights.map(\.weightKg), [80])
        XCTAssertEqual(weights.first?.note, "From Apple Health")
        let vitals = try context.fetch(FetchDescriptor<VitalsEntry>())
        XCTAssertEqual(vitals.count, 1, "Heart rate and sleep for the same day share an entry")
        XCTAssertEqual(vitals.first?.restingHeartRate, 59, "The latest reading of the day wins")
        XCTAssertEqual(vitals.first?.sleepHours, 7)
        let workouts = try context.fetch(FetchDescriptor<ExerciseEntry>())
        XCTAssertEqual(workouts.map(\.calories), [310])
        XCTAssertEqual(defaults.object(forKey: HealthSettings.lastImportKey) as? Date, now)

        let again = try await manager.importSamples(since: daysAgo(7), into: context)
        XCTAssertEqual(again, HealthImportSummary())
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WeightEntry>()), 1)
    }

    func testImportIfDueLooksBackNinetyDaysThenWaitsAQuarterHour() async throws {
        let first = await manager.importIfDue(into: context)
        XCTAssertNotNil(first)
        XCTAssertEqual(health.readSince.first, calendar.date(byAdding: .day, value: -90, to: now))

        now = now.addingTimeInterval(10 * 60)
        let tooSoon = await manager.importIfDue(into: context)
        XCTAssertNil(tooSoon)

        let lastImport = defaults.object(forKey: HealthSettings.lastImportKey) as? Date
        let forced = await manager.importIfDue(into: context, force: true)
        XCTAssertNotNil(forced)
        XCTAssertEqual(health.readSince.last, lastImport?.addingTimeInterval(-2 * 86_400),
                       "Re-reads two days before the last import to catch late syncs")
    }

    func testImportIfDueReportsAFailedRead() async {
        health.error = FakeHealthStore.Failure()

        let summary = await manager.importIfDue(into: context)

        XCTAssertNil(summary)
        XCTAssertEqual(manager.lastError, "Health said no")
        XCTAssertNil(defaults.object(forKey: HealthSettings.lastImportKey))
    }

    // MARK: Writes

    func testDiaryEntriesAreMirroredAndRemoved() async {
        let soup = entry()
        await wait(manager.recordDiaryEntry(soup))
        XCTAssertEqual(health.dietary[soup.uuid]?.foodName, "Soup")
        XCTAssertEqual(health.dietary[soup.uuid]?.values.first?.value, 320)

        // Changing the entry replaces what Health has rather than adding to it.
        soup.calories = 400
        await wait(manager.recordDiaryEntry(soup))
        XCTAssertEqual(health.dietary.count, 1)
        XCTAssertEqual(health.dietary[soup.uuid]?.values.first?.value, 400)

        await wait(manager.removeDiaryEntry(id: soup.uuid))
        XCTAssertTrue(health.dietary.isEmpty)
    }

    func testZeroCalorieEntriesAreSkippedUnlessTheyHaveCaffeine() async {
        XCTAssertNil(manager.recordDiaryEntry(entry(calories: 0)))

        let coffee = entry(calories: 0)
        coffee.caffeine = 95
        await wait(manager.recordDiaryEntry(coffee))
        XCTAssertNotNil(health.dietary[coffee.uuid])
    }

    func testWaterIsMirroredAndRemoved() async {
        let glass = WaterEntry(date: now, amountMl: 330)
        await wait(manager.recordWater(glass))
        XCTAssertEqual(health.water[glass.uuid], 330)

        await wait(manager.removeWater(id: glass.uuid))
        XCTAssertTrue(health.water.isEmpty)
    }

    func testAFailedWriteIsReported() async {
        health.error = FakeHealthStore.Failure()
        await wait(manager.recordWater(WaterEntry(date: now, amountMl: 250)))
        XCTAssertEqual(manager.lastError, "Health said no")
    }

    // MARK: Access and cycle

    func testAsksForAccessAgainOnlyWhenThereAreNewTypes() async {
        await manager.requestNewTypesIfNeeded()
        XCTAssertEqual(health.authorizationRequests, 0)

        health.unrequestedTypes = true
        await manager.requestNewTypesIfNeeded()
        XCTAssertEqual(health.authorizationRequests, 1)
    }

    func testRetentionDaysComeFromFlowDaysWhenCycleAwareWeightIsOn() async {
        let start = calendar.startOfDay(for: daysAgo(10))
        health.flowDays = [daysAgo(10), daysAgo(9), daysAgo(8)]

        await manager.refreshCycle()
        XCTAssertTrue(manager.retentionDays.isEmpty, "Off unless cycle-aware weight is on")

        defaults.set(true, forKey: CycleCalculator.enabledKey)
        await manager.refreshCycle()
        XCTAssertEqual(manager.retentionDays,
                       CycleCalculator.retentionDays(periodStarts: [start], today: now, calendar: calendar))
        XCTAssertTrue(manager.retentionDays.contains(start))

        defaults.set(false, forKey: CycleCalculator.enabledKey)
        await manager.refreshCycle()
        XCTAssertTrue(manager.retentionDays.isEmpty)
    }
}

/// The time the manager sees, moved on by tests.
private final class TestClock {
    var now = Date()
}
