import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject private var store: WatchStore

    var body: some View {
        NavigationStack {
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
                    NavigationLink {
                        LogFoodView()
                    } label: {
                        Label("Log food", systemImage: "fork.knife")
                    }
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

/// Favourite and recent foods from the phone, logged with one tap, plus a quick calorie add.
struct LogFoodView: View {
    @EnvironmentObject private var store: WatchStore
    @State private var logged: QuickFood.ID?

    private var energyUnit: String { store.snapshot?.energyUnit ?? "kcal" }

    var body: some View {
        List {
            NavigationLink {
                QuickAddCaloriesView()
            } label: {
                Label("Quick add", systemImage: "plus.circle")
            }
            if store.quickFoods.isEmpty {
                Text("Favourite or log foods on your iPhone and they'll appear here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Section("Favourites and recent") {
                    ForEach(store.quickFoods) { food in
                        Button {
                            store.log(food)
                            logged = food.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(food.name).lineLimit(2)
                                    Text(amount(food))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if logged == food.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                        .accessibilityLabel("Logged")
                                }
                            }
                        }
                        .accessibilityHint("Logs \(amount(food))")
                    }
                }
            }
        }
        .navigationTitle("Log food")
        .sensoryFeedback(.success, trigger: logged)
    }

    private func amount(_ food: QuickFood) -> String {
        let kcal = store.snapshot?.energy(food.kcal) ?? "\(Int(food.kcal.rounded()))"
        let servings = food.servings.formatted(.number.precision(.fractionLength(0...2)))
        return "\(servings) × · \(kcal) \(energyUnit)"
    }
}

/// Turn the Digital Crown to pick an amount, then log it.
struct QuickAddCaloriesView: View {
    @EnvironmentObject private var store: WatchStore
    @Environment(\.dismiss) private var dismiss
    @State private var kcal = 200.0

    var body: some View {
        VStack(spacing: 8) {
            Text("\(Int(kcal))")
                .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                .focusable()
                .digitalCrownRotation($kcal, from: 0, through: 2000, by: 10, sensitivity: .medium,
                                      isContinuous: false, isHapticFeedbackEnabled: true)
                .accessibilityLabel("\(Int(kcal)) calories")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: kcal = min(kcal + 10, 2000)
                    case .decrement: kcal = max(kcal - 10, 0)
                    @unknown default: break
                    }
                }
            Text("kcal · turn the crown")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button("Log") {
                store.quickAdd(kcal: kcal.rounded())
                dismiss()
            }
            .disabled(kcal <= 0)
        }
        .navigationTitle("Quick add")
    }
}
