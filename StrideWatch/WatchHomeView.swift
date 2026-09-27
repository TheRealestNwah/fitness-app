import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject private var store: WatchStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let s = store.snapshot {
                    calories(s)
                    water(s)
                } else {
                    Text("Open Stride on your iPhone to see today's totals.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    waterButton(250)
                    waterButton(500)
                }
            }
        }
        .sensoryFeedback(.success, trigger: store.snapshot?.waterMl)
    }

    private func calories(_ s: Snapshot) -> some View {
        ZStack {
            Circle().stroke(Color.accentColor.opacity(0.2), lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(max(s.progress, 0), 1))
                .stroke(s.progress > 1 ? Color.orange : Color.accentColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(s.energy(abs(s.remainingKcal)))
                    .font(.title3.bold().monospacedDigit())
                    .minimumScaleFactor(0.5)
                Text(s.remainingKcal >= 0 ? "\(s.energyUnit) left" : "\(s.energyUnit) over")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
        .frame(width: 100, height: 100)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(s.energy(abs(s.remainingKcal))) \(s.energyUnit) \(s.remainingKcal >= 0 ? "left" : "over") today")
    }

    private func water(_ s: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("\(Int(s.waterMl)) of \(Int(s.waterGoalMl)) ml", systemImage: "drop.fill")
                .font(.footnote.monospacedDigit())
            ProgressView(value: min(s.waterProgress, 1))
                .tint(.cyan)
        }
    }

    private func waterButton(_ ml: Double) -> some View {
        Button {
            store.logWater(ml)
        } label: {
            Text("+\(Int(ml))")
                .font(.headline.monospacedDigit())
        }
        .tint(.cyan)
        .accessibilityLabel("Log \(Int(ml)) millilitres of water")
    }
}
