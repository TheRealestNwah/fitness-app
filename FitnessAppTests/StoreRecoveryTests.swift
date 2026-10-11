import XCTest
import SwiftData
@testable import FitnessApp

final class StoreRecoveryTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testMovingAsideRenamesTheStoreAndItsCompanions() throws {
        for name in ["default.store", "default.store-shm", "default.store-wal", "unrelated.txt"] {
            try Data("x".utf8).write(to: folder.appending(path: name))
        }
        try FileManager.default.createDirectory(at: folder.appending(path: ".default_SUPPORT"), withIntermediateDirectories: true)

        let moved = try CloudSync.moveAside(storeAt: folder.appending(path: "default.store"), stamp: "1")

        XCTAssertEqual(Set(moved.map(\.lastPathComponent)),
                       ["default.store.broken-1", "default.store-shm.broken-1",
                        "default.store-wal.broken-1", ".default_SUPPORT.broken-1"])
        let left = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
        XCTAssertFalse(left.contains("default.store"))
        XCTAssertTrue(left.contains("unrelated.txt"))
    }

    func testMovingAsideSkipsFilesThatDontExist() throws {
        try Data("x".utf8).write(to: folder.appending(path: "default.store"))
        let moved = try CloudSync.moveAside(storeAt: folder.appending(path: "default.store"), stamp: "2")
        XCTAssertEqual(moved.map(\.lastPathComponent), ["default.store.broken-2"])
    }

    func testTheMigrationPlanOpensTheCurrentSchema() throws {
        let container = try ModelContainer(for: AppStore.schema, migrationPlan: StrideMigrationPlan.self,
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        XCTAssertEqual(StrideSchemaV1.models.count, AppStore.models.count)
        XCTAssertNotNil(container)
    }
}
