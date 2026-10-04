#if os(iOS)
import ActivityKit
#endif
import AppIntents
import Foundation
import SwiftData

/// A running fast on the Lock Screen and in the Dynamic Island. The widget extension declares
/// an identical type (StrideWidgets/FastingLiveActivity.swift); ActivityKit matches them by name.
#if os(iOS)
struct FastingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var targetEnd: Date
    }

    var sessionID: String
    var start: Date
    var targetHours: Double
}

#endif

/// What to do with Live Activities so exactly the running fast has one.
enum FastingActivityPlan {
    struct Running: Equatable {
        var id: String
        var start: Date
        var targetHours: Double
    }

    struct Changes: Equatable {
        var start: Running?
        var end: [String]
    }

    /// `showing` holds the session ids that already have an activity.
    static func changes(running: Running?, showing: [String]) -> Changes {
        guard let running else { return Changes(start: nil, end: showing) }
        return Changes(start: showing.contains(running.id) ? nil : running,
                       end: showing.filter { $0 != running.id })
    }
}

@MainActor
enum FastingActivityManager {
    /// Starts or ends Live Activities to match the fast in the store.
    static func sync(context: ModelContext) {
        #if os(iOS)
        let open = (try? context.fetch(FetchDescriptor<FastingSession>(predicate: #Predicate { $0.end == nil },
                                                                       sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
        let running = open.first.map { FastingActivityPlan.Running(id: $0.uuid.uuidString, start: $0.start, targetHours: $0.targetHours) }
        let activities = Activity<FastingActivityAttributes>.activities
        let changes = FastingActivityPlan.changes(running: running, showing: activities.map(\.attributes.sessionID))

        for activity in activities where changes.end.contains(activity.attributes.sessionID) {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        if let start = changes.start, ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = FastingActivityAttributes(sessionID: start.id, start: start.start, targetHours: start.targetHours)
            let targetEnd = start.start.addingTimeInterval(start.targetHours * 3600)
            _ = try? Activity.request(attributes: attributes,
                                      content: ActivityContent(state: .init(targetEnd: targetEnd), staleDate: nil))
        }
        #endif
    }
}

/// The Live Activity's End fast button. Runs in the app, which owns the store; the widget
/// extension has a matching declaration so the button can refer to it.
#if os(iOS)
struct EndFastIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Fast"
    static var isDiscoverable = false

    @Parameter(title: "Fast")
    var sessionID: String

    init() {}

    init(sessionID: String) {
        self.sessionID = sessionID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = AppStore.container.mainContext
        if let id = UUID(uuidString: sessionID),
           let session = try? context.fetch(FetchDescriptor<FastingSession>(predicate: #Predicate { $0.uuid == id })).first,
           session.end == nil {
            session.end = .now
            try? context.save()
        }
        FastingActivityManager.sync(context: context)
        return .result()
    }
}
#endif
