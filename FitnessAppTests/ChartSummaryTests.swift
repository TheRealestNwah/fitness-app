import XCTest
@testable import FitnessApp

final class ChartSummaryTests: XCTestCase {
    private let kg: (Double) -> String = { String(format: "%.1f kg", $0) }
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func testSummarisesChangeAndRange() {
        let points = [(start.addingTimeInterval(86_400 * 2), 81.0),
                      (start, 82.4),
                      (start.addingTimeInterval(86_400), 83.0),
                      (start.addingTimeInterval(86_400 * 3), 80.1)].map { (date: $0.0, value: $0.1) }
        let text = ChartSummary.describe(points, format: kg)
        XCTAssertTrue(text.hasPrefix("4 readings from"), text)
        XCTAssertTrue(text.contains("Started at 82.4 kg, latest 80.1 kg, down 2.3 kg"), text)
        XCTAssertTrue(text.contains("Lowest 80.1 kg, highest 83.0 kg"), text)
    }

    func testRisingAndFlat() {
        let up = ChartSummary.describe([(date: start, value: 120), (date: start.addingTimeInterval(86_400), value: 125)],
                                       format: { "\(Int($0)) mmHg" })
        XCTAssertTrue(up.contains("up 5 mmHg"), up)
        let flat = ChartSummary.describe([(date: start, value: 70), (date: start.addingTimeInterval(86_400), value: 70.01)],
                                         format: kg)
        XCTAssertTrue(flat.contains("no change"), flat)
    }

    func testEmptyAndSingle() {
        XCTAssertEqual(ChartSummary.describe([], format: kg), "No readings")
        XCTAssertTrue(ChartSummary.describe([(date: start, value: 70)], format: kg).hasPrefix("One reading, 70.0 kg"))
    }
}
