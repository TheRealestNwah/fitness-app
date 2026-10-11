import Foundation
import SwiftData

/// Optional iCloud sync through SwiftData's CloudKit integration, so an iPhone and an iPad
/// signed in to the same Apple ID share one diary.
///
/// Off by default and read once at launch, because the store's configuration can't change
/// while it's open. If iCloud isn't available (not signed in, or a build without the iCloud
/// capability), the app falls back to the on-device store and records why.
enum CloudSync {
    static let enabledKey = "iCloudSyncEnabled"
    static let containerIdentifier = "iCloud.com.stride.FitnessApp"

    static var isRequested: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Whether this launch is actually syncing.
    private(set) static var isActive = false
    /// Why sync was requested but isn't running, if so.
    private(set) static var problem: String?

    /// Why the on-device store couldn't be opened, if it couldn't. The app then runs on an empty
    /// in-memory store and shows `StoreRecoveryView` instead of crashing on every launch.
    private(set) static var openFailure: String?
    /// Where the on-device store lives, for moving a broken one aside.
    private(set) static var storeURL: URL?

    static func makeContainer(schema: Schema) -> ModelContainer {
        // UI tests and demos always run on-device.
        let wantsCloud = isRequested && !DemoData.shouldReset && !DemoData.shouldLoadDemo
        if wantsCloud {
            let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .private(containerIdentifier))
            do {
                let container = try ModelContainer(for: schema, migrationPlan: StrideMigrationPlan.self, configurations: [cloud])
                isActive = true
                return container
            } catch {
                problem = "iCloud isn't available, so data stays on this device. (\(error.localizedDescription))"
            }
        }
        let local = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        storeURL = local.url
        do {
            return try ModelContainer(for: schema, migrationPlan: StrideMigrationPlan.self, configurations: [local])
        } catch {
            // A store made before versioning was added opens without the plan.
            if let container = try? ModelContainer(for: schema, configurations: [local]) { return container }
            openFailure = error.localizedDescription
        }
        do {
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        } catch {
            fatalError("Could not create even an in-memory store: \(error)")
        }
    }

    /// Renames the store's files (database, journal and external data) with a `.broken-<stamp>`
    /// suffix so the next launch starts a fresh store while the old data stays on the device.
    @discardableResult
    static func moveAside(storeAt url: URL, stamp: String, fileManager: FileManager = .default) throws -> [URL] {
        let folder = url.deletingLastPathComponent()
        let name = url.lastPathComponent
        let related = [name, "\(name)-shm", "\(name)-wal", ".\(url.deletingPathExtension().lastPathComponent)_SUPPORT"]
        var moved: [URL] = []
        for file in related {
            let source = folder.appending(path: file)
            guard fileManager.fileExists(atPath: source.path(percentEncoded: false)) else { continue }
            let destination = folder.appending(path: "\(file).broken-\(stamp)")
            try fileManager.moveItem(at: source, to: destination)
            moved.append(destination)
        }
        return moved
    }
}

// MARK: - Schema versions

/// The data model as of 1.0. When a model changes, add a `StrideSchemaV2` holding copies of the
/// changed models, list it in `StrideMigrationPlan.schemas` and add a migration stage.
enum StrideSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { AppStore.models }
}

enum StrideMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StrideSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
