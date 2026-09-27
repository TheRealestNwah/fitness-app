import XCTest
@testable import FitnessApp

final class HealthReportTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private lazy var today = calendar.date(from: DateComponents(year: 2026, month: 6, day: 30, hour: 9))!

    private func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: today)! }

    func testKeepsOnlyThePeriodInOrder() {
        let report = HealthReport.make(
            weights: [(daysAgo(5), 80), (daysAgo(120), 90), (daysAgo(60), 84)],
            vitals: [.init(date: daysAgo(3), systolic: 130, diastolic: 85),
                     .init(date: daysAgo(200), systolic: 150, diastolic: 95),
                     .init(date: daysAgo(10))],
            today: today, calendar: calendar)
        XCTAssertEqual(report.weights.map(\.kg), [84, 80])
        XCTAssertEqual(report.weightChangeKg ?? 0, -4, accuracy: 0.001)
        XCTAssertEqual(report.readings.count, 1, "old and empty readings are left out")
    }

    func testAverages() {
        let report = HealthReport.make(
            weights: [],
            vitals: [.init(date: daysAgo(1), systolic: 130, diastolic: 80, heartRate: 60, glucose: 95),
                     .init(date: daysAgo(2), systolic: 121, diastolic: 83, heartRate: 70),
                     .init(date: daysAgo(3), waistCm: 90)],
            today: today, calendar: calendar)
        XCTAssertEqual(report.averageBloodPressure?.systolic, 126)
        XCTAssertEqual(report.averageBloodPressure?.diastolic, 82)
        XCTAssertEqual(report.averageHeartRate, 65)
        XCTAssertEqual(report.averageGlucose ?? 0, 95, accuracy: 0.001)
        XCTAssertNil(report.weightChangeKg)
    }
}
