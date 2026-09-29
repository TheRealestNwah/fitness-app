import SwiftUI
import SwiftData

/// A month at a glance, from Weight: the current month so far or any earlier one, shareable as an image.
struct MonthlyReportView: View {
    @Environment(UserProfile.self) private var profile
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var foodLogs: [FoodLogEntry]
    @Query private var fasts: [FastingSession]
    @Query private var exercise: [ExerciseEntry]

    /// A day inside the month shown; starts on last month for the first week of a month.
    @State private var monthDay = MonthlyReportView.defaultMonth()
    @State private var shareURL: URL?

    private var units: Units { profile.units }

    static func defaultMonth(today: Date = .now, calendar: Calendar = .current) -> Date {
        let day = calendar.component(.day, from: today)
        return day <= 7 ? calendar.date(byAdding: .month, value: -1, to: today) ?? today : today
    }

    private var report: MonthlyReport? {
        let currentKg = weights.last?.weightKg ?? profile.startWeightKg
        return MonthlyReportCalculator.report(
            month: monthDay,
            foodLogs: foodLogs.map { .init(date: $0.date, calories: $0.calories) },
            weights: weights.map { .init(date: $0.date, weightKg: $0.weightKg) },
            budget: profile.calorieTarget(currentWeightKg: currentKg),
            fasts: fasts.map { .init(start: $0.start, end: $0.end, targetHours: $0.targetHours) },
            workoutDates: exercise.map(\.date))
    }

    private var canGoForward: Bool {
        guard let next = Calendar.current.date(byAdding: .month, value: 1, to: monthDay) else { return false }
        return Calendar.current.dateInterval(of: .month, for: next).map { $0.start <= .now } ?? false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthPicker
                    if let report, report.hasContent {
                        MonthlyReportCard(report: report, units: units)
                    } else {
                        ContentUnavailableView("Nothing logged this month", systemImage: "calendar",
                                               description: Text("Weigh-ins, meals, fasts and workouts from this month will show up here."))
                    }
                }
                .padding()
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Monthly report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    if let shareURL {
                        ShareLink(item: shareURL) { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel("Share")
                    }
                }
            }
            .task(id: monthDay) { renderShareImage() }
            .onChange(of: weights.count) { renderShareImage() }
        }
    }

    private var monthPicker: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous month")
            Spacer()
            Text(monthDay.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next month")
                .disabled(!canGoForward)
        }
        .buttonStyle(.bordered)
    }

    private func shift(_ months: Int) {
        if let day = Calendar.current.date(byAdding: .month, value: months, to: monthDay) { monthDay = day }
    }

    private func renderShareImage() {
        guard let report, report.hasContent else { shareURL = nil; return }
        let renderer = ImageRenderer(content: MonthlyReportCard(report: report, units: units)
            .padding(24)
            .frame(width: 400)
            .background(Color(.systemGroupedBackground))
            .environment(\.colorScheme, .light))
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else { shareURL = nil; return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("monthly-report.png")
        shareURL = (try? data.write(to: url)).map { url }
    }
}

/// The report itself; also rendered as the share image.
struct MonthlyReportCard: View {
    var report: MonthlyReport
    var units: Units

    private var monthName: String { report.month.start.formatted(.dateTime.month(.wide).year()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(monthName)
                    .font(.title2.bold())
                Text(report.isComplete ? String(localized: "Whole month")
                                       : String(localized: "So far: \(report.daysSoFar) days"))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    StatTile(title: String(localized: "Trend change"),
                             value: report.changeKg.map { units.weightString(kg: $0, signed: true) } ?? "—",
                             subtitle: report.endTrendKg.map { String(localized: "now \(units.weightString(kg: $0))") },
                             systemImage: "scalemass.fill",
                             tint: (report.changeKg ?? 0) <= 0 ? .green : .orange)
                    StatTile(title: String(localized: "Best week"),
                             value: report.bestWeek.map { units.weightString(kg: $0.changeKg, signed: true) } ?? "—",
                             subtitle: report.bestWeek.map { String(localized: "from \($0.start.formatted(.dateTime.month(.abbreviated).day()))") },
                             systemImage: "star.fill", tint: .yellow)
                }
                GridRow {
                    StatTile(title: String(localized: "Days logged"),
                             value: "\(report.daysLogged)/\(report.daysSoFar)",
                             subtitle: String(localized: "longest run \(report.longestStreak)"),
                             systemImage: "calendar", tint: .indigo)
                    StatTile(title: String(localized: "Average intake"),
                             value: report.averageIntake.map { Energy.string($0) } ?? "—",
                             subtitle: String(localized: "budget \(Energy.string(Double(report.budget)))"),
                             systemImage: "fork.knife", tint: .green)
                }
                if report.completedFasts > 0 || report.workouts > 0 {
                    GridRow {
                        StatTile(title: String(localized: "Fasts completed"), value: "\(report.completedFasts)",
                                 systemImage: "timer", tint: .purple)
                        StatTile(title: String(localized: "Workouts"), value: "\(report.workouts)",
                                 systemImage: "figure.run", tint: .orange)
                    }
                }
            }
            Text("Tracked with Stride")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
    }
}
