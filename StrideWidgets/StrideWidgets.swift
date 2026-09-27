import SwiftUI
import WidgetKit

@main
struct StrideWidgetBundle: WidgetBundle {
    var body: some Widget {
        CaloriesWidget()
    }
}

struct SnapshotEntry: TimelineEntry {
    var date: Date
    var snapshot: Snapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : Snapshot.load() ?? .placeholder))
    }

    /// The app reloads the widgets whenever something is logged; the timeline only needs
    /// to roll over at midnight so yesterday's totals don't linger.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date.now
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
        let entries = [SnapshotEntry(date: now, snapshot: Snapshot.load(now: now)),
                       SnapshotEntry(date: midnight, snapshot: Snapshot.load(now: midnight))]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

struct CaloriesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CaloriesWidget", provider: SnapshotProvider()) { entry in
            CaloriesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Calories left, water and your latest weigh-in.")
        .supportedFamilies(Self.families)
    }

#if os(watchOS)
    static let families: [WidgetFamily] = [.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner]
#else
    static let families: [WidgetFamily] = [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
#endif
}

struct CaloriesWidgetView: View {
    var entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let s = entry.snapshot {
            switch family {
#if os(watchOS)
            case .accessoryCorner: corner(s)
#else
            case .systemMedium: medium(s)
#endif
            case .accessoryCircular: circular(s)
            case .accessoryRectangular: rectangular(s)
            case .accessoryInline: Text("\(s.energy(abs(s.remainingKcal))) \(s.energyUnit) \(s.remainingKcal >= 0 ? "left" : "over")")
            default: small(s)
            }
        } else {
            Text("Open Stride to start")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
    }

    private func ring(_ s: Snapshot, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Color.accentColor.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(s.progress, 0), 1))
                .stroke(s.progress > 1 ? Color.orange : Color.accentColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }

    private func small(_ s: Snapshot) -> some View {
        VStack(spacing: 6) {
            ZStack {
                ring(s, lineWidth: 10)
                VStack(spacing: 0) {
                    Text(s.energy(abs(s.remainingKcal)))
                        .font(.title2.bold().monospacedDigit())
                        .minimumScaleFactor(0.5)
                    Text(s.remainingKcal >= 0 ? "\(s.energyUnit) left" : "\(s.energyUnit) over")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }
            if s.streak > 1 {
                Label("\(s.streak) days", systemImage: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(s.energy(abs(s.remainingKcal))) \(s.energyUnit) \(s.remainingKcal >= 0 ? "left" : "over") today")
    }

    private func medium(_ s: Snapshot) -> some View {
        HStack(spacing: 16) {
            small(s)
            VStack(alignment: .leading, spacing: 10) {
                row("Eaten", "\(s.energy(s.consumedKcal)) of \(s.energy(Double(s.targetKcal))) \(s.energyUnit)", "fork.knife")
                VStack(alignment: .leading, spacing: 4) {
                    row("Water", "\(Int(s.waterMl)) of \(Int(s.waterGoalMl)) ml", "drop.fill")
                    ProgressView(value: min(s.waterProgress, 1)).tint(.cyan)
#if os(iOS)
                    Button(intent: LogGlassIntent()) {
                        Label("Glass", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                    }
                    .tint(.cyan)
                    .accessibilityLabel("Log a glass of water")
#endif
                }
                if let weight = s.weightText { row("Weight", weight, "scalemass.fill") }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(title, systemImage: icon).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit()).minimumScaleFactor(0.7)
        }
    }

    private func circular(_ s: Snapshot) -> some View {
        Gauge(value: min(max(s.progress, 0), 1)) {
            Image(systemName: "flame")
        } currentValueLabel: {
            Text(s.energy(abs(s.remainingKcal))).minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

#if os(watchOS)
    private func corner(_ s: Snapshot) -> some View {
        Text(s.energy(abs(s.remainingKcal)))
            .font(.title3.monospacedDigit())
            .widgetLabel {
                Gauge(value: min(max(s.progress, 0), 1)) { Text(s.energyUnit) }
            }
    }
#endif

    private func rectangular(_ s: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(s.energy(abs(s.remainingKcal))) \(s.energyUnit) \(s.remainingKcal >= 0 ? "left" : "over")")
                .font(.headline)
            Gauge(value: min(max(s.progress, 0), 1)) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
            if let weight = s.weightText {
                Text(weight).font(.caption)
            }
        }
    }
}
