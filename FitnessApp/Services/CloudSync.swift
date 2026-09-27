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

    static func makeContainer(schema: Schema) -> ModelContainer {
        // UI tests and demos always run on-device.
        let wantsCloud = isRequested && !DemoData.shouldReset && !DemoData.shouldLoadDemo
        if wantsCloud {
            let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .private(containerIdentifier))
            do {
                let container = try ModelContainer(for: schema, configurations: [cloud])
                isActive = true
                return container
            } catch {
                problem = "iCloud isn't available, so data stays on this device. (\(error.localizedDescription))"
            }
        }
        let local = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [local])
        } catch {
            fatalError("Could not create the data store: \(error)")
        }
    }
}
