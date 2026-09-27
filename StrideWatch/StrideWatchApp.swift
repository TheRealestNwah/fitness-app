import SwiftUI

@main
struct StrideWatchApp: App {
    @StateObject private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(store)
        }
    }
}
