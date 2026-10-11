import SwiftUI
import SwiftData

/// Choose what goes into a progress update for a friend, partner or coach, preview it, and send it
/// through the share sheet.
struct PartnerShareView: View {
    @Environment(UserProfile.self) private var profile
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var foodLogs: [FoodLogEntry]

    @AppStorage(PartnerSummary.weightTrendKey) private var weightTrend = true
    @AppStorage(PartnerSummary.weekKey) private var week = true
    @AppStorage(PartnerSummary.streaksKey) private var streaks = true
    @AppStorage(PartnerSummary.dailyCaloriesKey) private var dailyCalories = false

    private var options: PartnerSummary.Options {
        .init(weightTrend: weightTrend, week: week, streaks: streaks, dailyCalories: dailyCalories)
    }

    private var summary: String {
        let currentKg = weights.last?.weightKg ?? profile.startWeightKg
        let weightDays = weights.map { WeeklyReviewCalculator.WeightDay(date: $0.date, weightKg: $0.weightKg) }
        var calories: [Date: Double] = [:]
        var protein: [Date: Double] = [:]
        for entry in foodLogs {
            calories[entry.date.startOfDay, default: 0] += entry.calories
            protein[entry.date.startOfDay, default: 0] += entry.protein
        }
        let review = WeeklyReviewCalculator.review(
            foodLogs: foodLogs.map { WeeklyReviewCalculator.FoodDay(date: $0.date, calories: $0.calories) },
            weights: weightDays,
            budget: profile.calorieTarget(currentWeightKg: currentKg),
            plannedWeeklyLossKg: profile.weeklyLossKg)
        let input = PartnerSummary.Input(
            weights: weightDays,
            review: review,
            loggingStreak: NutritionCalculator.streak(logDates: foodLogs.map(\.date) + weights.map(\.date)),
            proteinStreak: NutritionCalculator.proteinStreak(proteinByDay: protein,
                                                             target: profile.macroTargets(currentWeightKg: currentKg).protein),
            caloriesByDay: calories,
            units: profile.units)
        return PartnerSummary.text(input, options: options)
    }

    var body: some View {
        let text = summary
        Form {
            Section {
                Toggle("Weight trend", isOn: $weightTrend)
                Toggle("Last 7 days", isOn: $week)
                Toggle("Streaks", isOn: $streaks)
                Toggle("Daily calorie totals", isOn: $dailyCalories)
                    .accessibilityIdentifier("partnerDailyCaloriesToggle")
            } header: {
                Text("Include")
            } footer: {
                Text("Individual foods and photos are never included. Weight is shown as a change, not your current weight.")
            }

            Section("Preview") {
                if text.isEmpty {
                    Text("Choose at least one thing to share.")
                        .foregroundStyle(Color.secondary)
                } else {
                    Text(text)
                        .font(.callout)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("partnerSummaryPreview")
                }
                if NumberPrivacy.shared.isOn {
                    Text("Numbers are hidden, so they show as dots. Turn off Hide numbers to share them.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }

            Section {
                ShareLink(item: text) {
                    Label("Share progress", systemImage: "square.and.arrow.up")
                }
                .disabled(text.isEmpty)
                .accessibilityIdentifier("partnerShareButton")
            } footer: {
                Text("Send it by Messages, Mail or any app. Nothing is sent until you choose where.")
            }
        }
        .navigationTitle("Share progress")
    }
}
