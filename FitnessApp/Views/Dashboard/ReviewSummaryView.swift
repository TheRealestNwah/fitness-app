import SwiftUI

/// The AI-written summary under the weekly review. Hidden unless the on-device model is available,
/// the user hasn't turned it off, and there is a summary to show.
struct ReviewSummaryView: View {
    let review: WeeklyReview
    let units: Units
    @AppStorage(ReviewSummarySettings.enabledKey) private var enabled = true
    @State private var text: String?
    @State private var isWriting = false

    private var facts: String { ReviewSummaryPrompt.facts(for: review, units: units) }

    var body: some View {
        Group {
            if enabled, ReviewSummaryWriter.isSupported {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Summary", systemImage: "sparkles")
                            .font(.footnote.weight(.semibold))
                        Spacer()
                        Button {
                            Task { await write(force: true) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isWriting)
                        .accessibilityLabel("Write a new summary")
                        .accessibilityIdentifier("regenerateSummary")
                    }
                    if let text {
                        Text(text)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("weeklySummaryText")
                    } else if isWriting {
                        ProgressView()
                    }
                    if text != nil {
                        Text("Written by AI on this device. It can make mistakes, and it isn't medical advice.")
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .padding(.top, 4)
                // A different week or different numbers means a different summary.
                .task(id: facts) { await write(force: false) }
            }
        }
    }

    private func write(force: Bool) async {
        if !force, let cached = ReviewSummaryCache.cached(for: facts) {
            text = cached
            return
        }
        isWriting = true
        defer { isWriting = false }
        if let written = await ReviewSummaryWriter.summary(for: review, units: units) {
            ReviewSummaryCache.store(written, for: facts)
            text = written
        } else if force {
            text = ReviewSummaryCache.cached(for: facts)
        }
    }
}

/// Settings toggle, shown only where the on-device model can run.
struct ReviewSummarySection: View {
    @AppStorage(ReviewSummarySettings.enabledKey) private var enabled = true

    var body: some View {
        if ReviewSummaryWriter.isSupported {
            Section {
                Toggle("AI summary in the weekly review", isOn: $enabled)
                    .accessibilityIdentifier("aiSummaryToggle")
            } footer: {
                Text("Apple Intelligence writes a short summary from your week's totals. It runs on this device and your diary isn't sent anywhere. Turn it off to keep only the fixed tips.")
            }
        }
    }
}
