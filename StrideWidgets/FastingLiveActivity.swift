#if os(iOS)
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Mirror of the app's `FastingActivityAttributes`; the two must stay identical.
struct FastingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var targetEnd: Date
    }

    var sessionID: String
    var start: Date
    var targetHours: Double
}

/// Declared here so the button can use it; as a LiveActivityIntent it runs in the app,
/// whose version ends the fast.
struct EndFastIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Fast"
    static var isDiscoverable = false

    @Parameter(title: "Fast")
    var sessionID: String

    init() {}

    init(sessionID: String) {
        self.sessionID = sessionID
    }

    func perform() async throws -> some IntentResult { .result() }
}

struct FastingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FastingActivityAttributes.self) { context in
            FastingLockScreenView(attributes: context.attributes, state: context.state)
                .padding()
                .activityBackgroundTint(Color.indigo.opacity(0.15))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Fasting", systemImage: "timer").font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.start...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                        .frame(maxWidth: 80)
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(timerInterval: context.attributes.start...context.state.targetEnd, countsDown: false) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(.indigo)
                        Button(intent: EndFastIntent(sessionID: context.attributes.sessionID)) {
                            Text("End fast").font(.caption.weight(.semibold))
                        }
                        .tint(.orange)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(.indigo)
            } compactTrailing: {
                Text(timerInterval: context.attributes.start...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(.indigo)
            }
        }
    }
}

struct FastingLockScreenView: View {
    var attributes: FastingActivityAttributes
    var state: FastingActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("\(Int(attributes.targetHours))-hour fast", systemImage: "timer")
                    .font(.headline)
                Spacer()
                Text(timerInterval: attributes.start...Date.distantFuture, countsDown: false)
                    .font(.headline.monospacedDigit())
                    .multilineTextAlignment(.trailing)
            }
            ProgressView(timerInterval: attributes.start...state.targetEnd, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.indigo)
            HStack {
                Text("Target \(state.targetEnd.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(intent: EndFastIntent(sessionID: attributes.sessionID)) {
                    Text("End fast").font(.caption.weight(.semibold))
                }
                .tint(.orange)
            }
        }
    }
}
#endif
