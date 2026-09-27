#if os(iOS)
import AppIntents
import SwiftUI
import WidgetKit

/// Control Center, Lock Screen and Action button control (iOS 18). Logs a glass through the
/// same queue as the widget's button, so the app adds it to the diary.
@available(iOS 18.0, *)
struct LogWaterControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LogWaterControl") {
            ControlWidgetButton(action: LogGlassIntent()) {
                Label("Log water", systemImage: "drop.fill")
            }
        }
        .displayName("Log water")
        .description("Adds a glass to today's water in Stride.")
    }
}
#endif
