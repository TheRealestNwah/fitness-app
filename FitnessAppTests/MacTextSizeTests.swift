import SwiftUI
import XCTest
@testable import FitnessApp

final class MacTextSizeTests: XCTestCase {
    func testDefaultIsLarge() {
        XCTAssertEqual(MacTextSize.default, .large)
    }

    func testStandardIsTheMacScaleAndLargerIsTheIPhoneScale() {
        XCTAssertEqual(MacTextSize.standard.size(for: .body), 13)
        XCTAssertEqual(MacTextSize.standard.size(for: .largeTitle), 26)
        XCTAssertEqual(MacTextSize.larger.size(for: .body), 17)
        XCTAssertEqual(MacTextSize.larger.size(for: .largeTitle), 34)
        XCTAssertEqual(MacTextSize.large.size(for: .body), 13 * 1.15, accuracy: 0.001)
    }

    func testEveryStyleGrowsWithEachStep() {
        for style in Font.TextStyle.allCases {
            XCTAssertLessThan(MacTextSize.standard.size(for: style), MacTextSize.large.size(for: style), "\(style)")
            XCTAssertLessThan(MacTextSize.large.size(for: style), MacTextSize.larger.size(for: style), "\(style)")
        }
    }

    func testCurrentReadsTheSettingAndFallsBack() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: MacTextSize.storageKey)
        defer { defaults.set(saved, forKey: MacTextSize.storageKey) }
        defaults.set("larger", forKey: MacTextSize.storageKey)
        XCTAssertEqual(MacTextSize.current, .larger)
        defaults.set("huge", forKey: MacTextSize.storageKey)
        XCTAssertEqual(MacTextSize.current, .default)
        defaults.removeObject(forKey: MacTextSize.storageKey)
        XCTAssertEqual(MacTextSize.current, .default)
    }
}
