import XCTest
@testable import FitnessApp

final class HealthDismissalsTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        suiteName = "HealthDismissalsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDismissedIDsAreRememberedPerKind() {
        HealthDismissals.dismiss(["a", "b"], kind: .workout, defaults: defaults)
        XCTAssertEqual(HealthDismissals.ids(.workout, defaults: defaults), ["a", "b"])
        XCTAssertTrue(HealthDismissals.ids(.weight, defaults: defaults).isEmpty)
    }

    func testRestoreForgetsOnlyThoseIDs() {
        HealthDismissals.dismiss(["a", "b"], kind: .weight, defaults: defaults)
        HealthDismissals.restore(["a"], kind: .weight, defaults: defaults)
        XCTAssertEqual(HealthDismissals.ids(.weight, defaults: defaults), ["b"])
    }

    func testListKeepsTheMostRecentAndHasNoDuplicates() {
        let old = (0..<HealthDismissals.limit).map { "old\($0)" }
        HealthDismissals.dismiss(old, kind: .workout, defaults: defaults)
        HealthDismissals.dismiss(["old0", "new"], kind: .workout, defaults: defaults)

        let list = defaults.stringArray(forKey: HealthDismissals.key(.workout)) ?? []
        XCTAssertEqual(list.count, HealthDismissals.limit)
        XCTAssertEqual(list.suffix(2), ["old0", "new"])
        XCTAssertFalse(list.contains("old1"))
    }
}
