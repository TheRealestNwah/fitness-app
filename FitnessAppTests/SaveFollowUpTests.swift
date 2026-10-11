import XCTest
@testable import FitnessApp

@MainActor
final class SaveFollowUpTests: XCTestCase {
    func testABurstRunsTheLatestWorkOnce() async throws {
        let followUp = SaveFollowUp()
        var runs: [Int] = []
        for i in 1...5 {
            followUp.schedule(after: .milliseconds(50)) { runs.append(i) }
        }
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(runs, [5])
    }
}
