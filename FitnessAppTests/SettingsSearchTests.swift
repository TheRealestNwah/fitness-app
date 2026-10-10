import XCTest
@testable import FitnessApp

final class SettingsSearchTests: XCTestCase {
    private func titles(_ query: String) -> [String] {
        SettingsSearch.search(query).map(\.title)
    }

    func testEmptyQueryFindsNothing() {
        XCTAssertTrue(titles("").isEmpty)
        XCTAssertTrue(titles("   ").isEmpty)
    }

    func testFindsBySettingName() {
        XCTAssertEqual(SettingsSearch.search("macro").first?.page, .nutrition)
        XCTAssertTrue(titles("appearance").contains("Appearance"))
    }

    func testFindsByKeyword() {
        XCTAssertEqual(titles("dark mode"), ["Appearance"])
        XCTAssertEqual(SettingsSearch.search("face id").first?.page, .privacy)
    }

    func testFindsTheTipLinkInAbout() {
        XCTAssertEqual(SettingsSearch.search("coffee").first?.page, .about)
        XCTAssertEqual(SettingsSearch.search("open source").first?.page, .about)
    }

    func testIgnoresCaseAndAccents() {
        XCTAssertEqual(titles("ICLOUD"), titles("icloud"))
        XCTAssertEqual(titles("fibré"), titles("fibre"))
        XCTAssertFalse(titles("fibre").isEmpty)
    }

    func testEveryWordMustMatch() {
        XCTAssertEqual(titles("protein check"), ["Protein check"])
        XCTAssertTrue(titles("protein zebra").isEmpty)
    }

    func testTitleMatchesComeFirst() {
        // "Protein check" has protein in its title; "Macro split" only as a keyword.
        XCTAssertEqual(titles("protein"), ["Protein check", "Macro split"])
    }

    func testEveryPageHasSearchableSettings() {
        for page in SettingsPage.allCases {
            XCTAssertTrue(SettingsSearch.entries.contains { $0.page == page }, "\(page.title) has no search entries")
        }
    }

    func testEntryIDsAreUnique() {
        let ids = SettingsSearch.entries.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
