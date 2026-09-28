import SwiftUI
import SwiftData

struct DashboardView: View {
    var selectTab: (MainTabView.Tab) -> Void

    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass

    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \VitalsEntry.date, order: .reverse) private var vitals: [VitalsEntry]
    @Query private var todaysFood: [FoodLogEntry]
    @Query private var todaysWater: [WaterEntry]
    @Query private var recentFood: [FoodLogEntry]
    @Query private var recentWeights: [WeightEntry]
    @Query private var todaysPlan: [MealPlanEntry]
    @Query private var todaysExercise: [ExerciseEntry]
    @Query(sort: \FastingSession.start, order: .reverse) private var fasts: [FastingSession]

    @State private var showAddWeight = false
    @State private var showAddFood = false
    @State private var showAddVitals = false
    @State private var showSettings = false
    @State private var showQuickAdd = false
    @ScaledMetric(relativeTo: .title) private var ringSize: CGFloat = 130
    @State private var showLayoutEditor = false
    @AppStorage(TodayLayoutEditor.storageKey) private var layoutStorage = ""

    init(day: Date = .now, selectTab: @escaping (MainTabView.Tab) -> Void) {
        self.selectTab = selectTab
        let start = Calendar.current.startOfDay(for: day)
        let end = start.adding(days: 1)
        let sixtyDaysAgo = start.adding(days: -60)
        _todaysFood = Query(filter: #Predicate<FoodLogEntry> { $0.date >= start && $0.date < end },
                            sort: \FoodLogEntry.date)
        _todaysWater = Query(filter: #Predicate<WaterEntry> { $0.date >= start && $0.date < end })
        _recentFood = Query(filter: #Predicate<FoodLogEntry> { $0.date >= sixtyDaysAgo })
        _recentWeights = Query(filter: #Predicate<WeightEntry> { $0.date >= sixtyDaysAgo })
        _todaysPlan = Query(filter: #Predicate<MealPlanEntry> { $0.day >= start && $0.day < end })
        _todaysExercise = Query(filter: #Predicate<ExerciseEntry> { $0.date >= start && $0.date < end })
    }

    // MARK: Derived

    private var units: Units { profile.units }
    private var currentKg: Double { weights.first?.weightKg ?? profile.startWeightKg }
    private var dailyTarget: Int { profile.calorieTarget(currentWeightKg: currentKg) }

    private var intakeByDay: [Date: Double] {
        var totals: [Date: Double] = [:]
        for entry in recentFood { totals[entry.date.startOfDay, default: 0] += entry.calories }
        return totals
    }

    /// Today's share of the week when weekly budgeting is on (not during a break or maintenance).
    private var baseTarget: Int {
        guard profile.weeklyBudgetEnabled, !profile.isOnDietBreak, !profile.isMaintaining,
              profile.customCalorieTarget == nil else { return dailyTarget }
        return BudgetCalculator.weeklyAdjustedTarget(dailyTarget: dailyTarget, intakeByDay: intakeByDay,
                                                     floor: NutritionCalculator.calorieFloor(for: profile.sex))
    }
    /// Calories added back from activity: Health active energy or logged exercise, whichever is larger.
    private var activeCredit: Int {
        ExerciseCatalog.combinedCredit(
            health: HealthKitManager.shared.activeEnergyCredit,
            exercise: ExerciseCatalog.earnBack(exerciseKcal: todaysExercise.reduce(0) { $0 + $1.calories },
                                               percent: ExerciseSettings.earnBackPercent))
    }
    private var calorieTarget: Int { baseTarget + activeCredit }
    private var macroTargets: MacroTargets { profile.macroTargets(currentWeightKg: currentKg) }

    private var consumed: Double { todaysFood.reduce(0) { $0 + $1.calories } }
    private var protein: Double { todaysFood.reduce(0) { $0 + $1.protein } }
    private var carbs: Double { todaysFood.reduce(0) { $0 + $1.carbs } }
    private var fat: Double { todaysFood.reduce(0) { $0 + $1.fat } }
    private var waterMl: Double { todaysWater.reduce(0) { $0 + $1.amountMl } }

    private var streak: Int {
        NutritionCalculator.streak(logDates: recentFood.map(\.date) + recentWeights.map(\.date))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let base: String
        switch hour {
        case 5..<12: base = "Good morning"
        case 12..<17: base = "Good afternoon"
        default: base = "Good evening"
        }
        return profile.name.isEmpty ? base : "\(base), \(profile.name)"
    }

    private var weeklyReview: WeeklyReview {
        WeeklyReviewCalculator.review(
            foodLogs: recentFood.map { WeeklyReviewCalculator.FoodDay(date: $0.date, calories: $0.calories) },
            weights: weights.map { WeeklyReviewCalculator.WeightDay(date: $0.date, weightKg: $0.weightKg) },
            budget: calorieTarget,
            plannedWeeklyLossKg: profile.weeklyLossKg,
            fasts: fasts.map { FastingCalculator.Fast(start: $0.start, end: $0.end, targetHours: $0.targetHours) })
    }

    private var weightDays: [WeeklyReviewCalculator.WeightDay] {
        weights.map { WeeklyReviewCalculator.WeightDay(date: $0.date, weightKg: $0.weightKg) }
    }

    private var recentMilestone: Milestone? {
        ProgressCalculator.recentMilestone(startKg: profile.startWeightKg, weights: weightDays)
    }

    private var plateau: Plateau? {
        guard !profile.isMaintaining else { return nil }      // holding steady is the point
        let estimate = AdaptiveTargetCalculator.estimate(
            foodLogs: recentFood.map { WeeklyReviewCalculator.FoodDay(date: $0.date, calories: $0.calories) },
            weights: weightDays)
        return ProgressCalculator.plateau(weights: weightDays, goalKg: profile.goalWeightKg,
                                          currentTarget: baseTarget, maintenance: estimate,
                                          weeklyLossKg: profile.weeklyLossKg, sex: profile.sex)
    }

    private var tip: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return SeedData.tips[day % SeedData.tips.count]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    cards
                    customiseButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showAddWeight) { AddWeightSheet() }
            .sheet(isPresented: $showAddFood) { FoodSearchView(date: Date.now.startOfDay, mealType: MealType.current()) }
            .sheet(isPresented: $showAddVitals) { AddVitalsSheet() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .modifier(TodayHaptics(foodCount: todaysFood.count, weighIns: weights.count,
                                   waterMl: waterMl, waterGoalMl: profile.waterGoalMl, streak: streak))
        }
    }

    // MARK: Sections

    /// One column on iPhone; two side by side on iPad and other wide windows.
    @ViewBuilder
    private var cards: some View {
        let visible = TodayLayout(storage: layoutStorage).visible
        if sizeClass == .regular {
            let split = TodayLayout.columns(visible)
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) { ForEach(split.left) { cardView($0) } }
                VStack(spacing: 16) { ForEach(split.right) { cardView($0) } }
            }
        } else {
            ForEach(visible) { cardView($0) }
        }
    }

    @ViewBuilder
    private func cardView(_ card: TodayCard) -> some View {
        switch card {
        case .calories: calorieCard
        case .quickActions: quickActions
        case .suggestions:
            SuggestionsCard(remaining: .init(kcal: Double(calorieTarget) - consumed, protein: macroTargets.protein - protein,
                                             carbs: macroTargets.carbs - carbs, fat: macroTargets.fat - fat),
                            target: .init(kcal: Double(calorieTarget), protein: macroTargets.protein,
                                          carbs: macroTargets.carbs, fat: macroTargets.fat))
        case .weight: weightCard
        case .progress:
            if let milestone = recentMilestone { milestoneCard(milestone) }
            if let plateau { plateauCard(plateau) }
        case .activity:
            if HealthSettings.isEnabled, HealthKitManager.isAvailable { activityCard }
        case .weeklyReview:
            if weeklyReview.hasContent { weeklyReviewCard }
        case .water: waterCard
        case .plan:
            if !todaysPlan.isEmpty { planCard }
        case .vitals: vitalsCard
        case .tip: tipCard
        case .exercise: ExerciseCard(weightKg: currentKg)
        case .fasting: FastingCard()
        }
    }

    private var customiseButton: some View {
        Button { showLayoutEditor = true } label: {
            Label("Customise Today", systemImage: "slider.horizontal.3")
                .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .padding(.top, 4)
        .sheet(isPresented: $showLayoutEditor) { TodayLayoutEditor() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.title2.bold())
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            if streak > 0 {
                Label("\(streak) days", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }
        }
    }

    private var calorieCard: some View {
        let remaining = Double(calorieTarget) - consumed
        return VStack(spacing: 16) {
            AdaptiveStack(spacing: 20) {
                ZStack {
                    ProgressRing(progress: Double(calorieTarget) > 0 ? consumed / Double(calorieTarget) : 0, lineWidth: 14)
                    VStack(spacing: 2) {
                        Text(Energy.number(abs(remaining)))
                            .font(.title.bold().monospacedDigit())
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(remaining >= 0 ? "left" : "over")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(14)
                }
                .frame(width: ringSize, height: ringSize)
                .contentShape(Circle())
                .contextMenu { ringActions }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Calories today")
                .accessibilityValue(remaining >= 0
                    ? "\(Int(consumed.rounded())) eaten of \(calorieTarget), \(Int(remaining.rounded())) left"
                    : "\(Int(consumed.rounded())) eaten of \(calorieTarget), \(Int((-remaining).rounded())) over")
                .accessibilityHint("Touch and hold for quick actions")

                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("Eaten", value: Energy.string(consumed))
                    LabeledContent("Budget", value: activeCredit > 0 ? "\(Energy.number(baseTarget)) + \(Energy.string(activeCredit))" : Energy.string(calorieTarget))
                    if let note = budgetNote {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    Divider()
                    MacroBar(name: "Protein", consumed: protein, target: macroTargets.protein, color: .blue)
                    MacroBar(name: "Carbs", consumed: carbs, target: macroTargets.carbs, color: .orange)
                    MacroBar(name: "Fat", consumed: fat, target: macroTargets.fat, color: .pink)
                }
                .font(.subheadline.monospacedDigit())
            }
            Button {
                selectTab(.food)
            } label: {
                HStack {
                    Text(todaysFood.isEmpty ? "Nothing logged yet" : "\(todaysFood.count) items logged")
                    Spacer()
                    Text("Open diary")
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline)
            }
        }
        .card()
        // Kept on the card rather than the body, which is near the type checker's limit.
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet(date: Date.now.startOfDay, mealType: MealType.current())
        }
    }

    private var budgetNote: String? {
        if profile.isOnDietBreak, let end = profile.dietBreakEnd {
            return "Diet break: eating at maintenance until \(end.longDateLabel())."
        }
        guard baseTarget != dailyTarget else { return nil }
        let balance = BudgetCalculator.weekBalance(dailyTarget: dailyTarget, intakeByDay: intakeByDay)
        return balance >= 0 ? "Weekly budget: \(Energy.string(balance)) banked this week."
                            : "Weekly budget: \(Energy.string(-balance)) over so far this week."
    }

    // MARK: Ring quick actions

    private var yesterdaysCurrentMeal: [FoodLogEntry] {
        let meal = MealType.current()
        let today = Date.now.startOfDay
        let yesterday = today.adding(days: -1)
        return recentFood
            .filter { $0.mealType == meal && $0.date >= yesterday && $0.date < today }
            .sorted { $0.date < $1.date }
    }

    @ViewBuilder
    private var ringActions: some View {
        let meal = MealType.current()
        let yesterdays = yesterdaysCurrentMeal
        let kcal: Int = Int(yesterdays.reduce(0.0) { $0 + $1.calories }.rounded())
        let name: String = meal.inSentence
        let copyTitle: String = yesterdays.isEmpty ? "No \(name) logged yesterday"
            : "Copy yesterday's \(name) (\(Energy.string(kcal)))"
        Button { showAddFood = true } label: {
            Label("Add food", systemImage: "plus.circle")
        }
        Button { showQuickAdd = true } label: {
            Label("Quick add calories", systemImage: "bolt")
        }
        Button { copyYesterday(yesterdays, as: meal) } label: {
            Label(copyTitle, systemImage: "arrow.uturn.backward")
        }
        .disabled(yesterdays.isEmpty)
    }

    private func copyYesterday(_ entries: [FoodLogEntry], as meal: MealType) {
        let stamp = meal.logDate(on: Date.now.startOfDay)
        for e in entries {
            context.insertDiaryEntry(FoodLogEntry(date: stamp, mealType: meal, foodName: e.foodName, servings: e.servings,
                                                  servingDescription: e.servingDescription, calories: e.calories,
                                                  protein: e.protein, carbs: e.carbs, fat: e.fat, foodItemID: e.foodItemID,
                                                  fiber: e.fiber, sugar: e.sugar, sodium: e.sodium))
        }
        try? context.save()
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionButton(title: "Log food", systemImage: "fork.knife", tint: .green) { showAddFood = true }
            QuickActionButton(title: "Weigh in", systemImage: "scalemass", tint: .indigo) { showAddWeight = true }
            QuickActionButton(title: "Vitals", systemImage: "heart.fill", tint: .red) { showAddVitals = true }
            QuickActionButton(title: "Water", systemImage: "drop.fill", tint: .cyan) { addWater() }
        }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                selectTab(.weight)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(profile.isMaintaining ? "Maintaining" : "Weight", systemImage: "scalemass.fill")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    weightHeadline
                    if profile.isMaintaining {
                        MaintenanceBandView(trendKg: ProgressCalculator.trend(on: .now, weights: weightDays) ?? currentKg,
                                            centerKg: profile.maintenanceCenterKg,
                                            bandKg: profile.maintenanceBandKg, units: units)
                    } else {
                        goalProgress
                    }
                }
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            if MaintenanceCalculator.shouldOffer(trendKg: ProgressCalculator.trend(on: .now, weights: weightDays),
                                                 goalKg: profile.goalWeightKg,
                                                 isMaintaining: profile.isMaintaining) {
                Divider()
                maintenanceOffer
            }
        }
        .card()
    }

    private var weightHeadline: some View {
        let lost = profile.startWeightKg - currentKg
        let daysSinceWeighIn = weights.first.map { Calendar.current.dateComponents([.day], from: $0.date.startOfDay, to: Date.now.startOfDay).day ?? 0 }
        return HStack(alignment: .firstTextBaseline) {
            Text(units.weightString(kg: currentKg))
                .font(.title.bold().monospacedDigit())
            Text(units.weightString(kg: -lost, signed: true))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(lost >= 0 ? .green : .orange)
            Spacer()
            if let days = daysSinceWeighIn, days > 0 {
                Text(days == 1 ? "Yesterday" : "\(days) days ago")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    private var goalProgress: some View {
        let lost = profile.startWeightKg - currentKg
        let remaining = max(currentKg - profile.goalWeightKg, 0)
        let total = max(profile.startWeightKg - profile.goalWeightKg, 0.001)
        let progress = min(max(lost / total, 0), 1)
        let projected = BudgetCalculator.goalDate(
            NutritionCalculator.projectedGoalDate(currentKg: currentKg, goalKg: profile.goalWeightKg, weeklyLossKg: profile.weeklyLossKg),
            breakStart: profile.dietBreakStart, breakEnd: profile.dietBreakEnd)
        return VStack(alignment: .leading, spacing: 12) {
            ProgressView(value: progress)
                .tint(.indigo)
            HStack {
                Text("\(units.weightString(kg: remaining)) to go")
                Spacer()
                if remaining == 0 {
                    Text("Goal reached!")
                } else if let projected {
                    Text("ETA \(projected.shortDateLabel())")
                }
            }
            .font(.caption)
            .foregroundStyle(Color.secondary)
        }
    }

    private var maintenanceOffer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("You've reached your goal", systemImage: "party.popper.fill")
                .font(.subheadline.weight(.semibold))
            Text("Switch to maintenance: your target becomes your maintenance calories, and you'll hold \(units.weightString(kg: profile.goalWeightKg)) within ± \(units.weightString(kg: MaintenanceCalculator.defaultBandKg)).")
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Switch to maintenance") {
                profile.startMaintenance(atKg: profile.goalWeightKg)
                try? context.save()
            }
            .buttonStyle(.borderedProminent)
            .font(.subheadline)
        }
    }

    private var activityCard: some View {
        let health = HealthKitManager.shared
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Activity", systemImage: "figure.walk")
                    .font(.headline)
                Spacer()
                Text("Apple Health")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            HStack(spacing: 12) {
                StatTile(title: "Steps", value: health.todaySteps.formatted(), subtitle: "today", systemImage: "shoeprints.fill", tint: .green)
                StatTile(title: "Active energy", value: "\(Energy.string(health.todayActiveEnergyKcal))",
                         subtitle: activeCredit > 0 ? "+\(Energy.string(activeCredit)) to budget" : "not added to budget",
                         systemImage: "flame.fill", tint: .orange)
            }
            if let error = health.lastError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
        }
        .card()
    }

    private func milestoneCard(_ milestone: Milestone) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(milestone.percent)% of your starting weight lost")
                    .font(.headline)
                Text("Your 7-day average passed \(units.weightString(kg: milestone.thresholdKg)) on \(milestone.reachedOn.longDateLabel()). That's a real change, not a good morning.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private func plateauCard(_ plateau: Plateau) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Weight has held steady for \(plateau.days) days", systemImage: "chart.line.flattrend.xyaxis")
                .font(.headline)
            Text("Your 7-day average has stayed around \(units.weightString(kg: plateau.trendKg)). Plateaus are normal; a few things worth checking:")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(plateau.suggestions, id: \.self) { suggestion in
                Label {
                    Text(suggestion).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "checkmark.circle").foregroundStyle(.indigo)
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var weeklyReviewCard: some View {
        let review = weeklyReview
        let intakeValue = review.averageIntake.map { "\(Energy.string($0))" } ?? "—"
        let intakeSubtitle: String = {
            guard let over = review.overBudget else { return "budget \(review.budget)" }
            if abs(over) < 25 { return "on budget" }
            return over > 0 ? "\(Int(over.rounded())) over budget" : "\(Int((-over).rounded())) under budget"
        }()
        let weightValue = review.weightChangeKg.map { units.weightString(kg: $0, signed: true) } ?? "—"
        let weightSubtitle = review.weightChangeKg == nil
            ? "needs two weeks of weigh-ins"
            : "plan \(units.weightString(kg: -review.plannedWeeklyLossKg, signed: true))"
        let intakeTint: Color = (review.overBudget ?? 0) > Double(review.budget) * 0.10 ? .orange : .green
        let weightTint: Color = (review.weightChangeKg ?? 0) <= 0 ? .green : .orange

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Last 7 days", systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
                Text("\(review.daysLogged)/7 days logged")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            HStack(spacing: 12) {
                StatTile(title: "Average intake", value: intakeValue, subtitle: intakeSubtitle,
                         systemImage: "fork.knife", tint: intakeTint)
                StatTile(title: "Weight change", value: weightValue, subtitle: weightSubtitle,
                         systemImage: "scalemass", tint: weightTint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(review.headline)
                    .font(.subheadline.weight(.semibold))
                Text(review.suggestion)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if review.completedFasts > 0 {
                Label("\(review.completedFasts) fasts completed", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
        .card()
    }

    private var waterCard: some View {
        let goal = profile.waterGoalMl
        let glasses = Int((waterMl / units.glassMl).rounded(.down))
        let goalGlasses = Int((goal / units.glassMl).rounded(.up))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Water", systemImage: "drop.fill")
                    .font(.headline)
                Spacer()
                Text("\(units.volumeString(ml: waterMl)) / \(units.volumeString(ml: goal))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("waterTotal")
            }
            HStack(spacing: 6) {
                // A weight-based goal can mean 15+ glasses; one drop each would push the card
                // (and the whole dashboard) wider than the screen, so fall back to a bar.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        ForEach(0..<max(goalGlasses, 1), id: \.self) { i in
                            Image(systemName: i < glasses ? "drop.fill" : "drop")
                                .foregroundStyle(i < glasses ? Color.cyan : Color.secondary.opacity(0.4))
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(glasses) of \(max(goalGlasses, 1)) glasses")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                        ProgressView(value: Double(min(glasses, goalGlasses)), total: Double(max(goalGlasses, 1)))
                            .tint(.cyan)
                    }
                }
                Spacer(minLength: 8)
                Button {
                    removeWater()
                } label: {
                    Image(systemName: "minus.circle")
                }
                .disabled(todaysWater.isEmpty)
                Button {
                    addWater()
                } label: {
                    Label("Glass", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .accessibilityIdentifier("addGlass")
            }
        }
        .card()
    }

    private var planCard: some View {
        let planned = todaysPlan.reduce(0) { $0 + $1.totalCalories }
        return Button {
            selectTab(.plan)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Today's plan", systemImage: "calendar")
                        .font(.headline)
                    Spacer()
                    Text("\(Energy.string(planned)) planned")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                ForEach(todaysPlan.sorted { $0.mealType.order < $1.mealType.order }) { entry in
                    HStack {
                        Image(systemName: entry.mealType.systemImage)
                            .foregroundStyle(Color.secondary)
                            .frame(width: 20)
                        Text(entry.title)
                            .lineLimit(1)
                        Spacer()
                        if entry.isLogged {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Text("\(Int(entry.totalCalories.rounded()))")
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
        .buttonStyle(.plain)
        .tappableCard()
    }

    private var vitalsCard: some View {
        Button {
            selectTab(.vitals)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Vitals", systemImage: "heart.text.square.fill")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                if let bp = vitals.first(where: { $0.systolic != nil && $0.diastolic != nil }),
                   let sys = bp.systolic, let dia = bp.diastolic {
                    LabeledContent("Blood pressure", value: "\(sys)/\(dia) · \(NutritionCalculator.bloodPressureCategory(systolic: sys, diastolic: dia).label)")
                }
                if let hr = vitals.first(where: { $0.restingHeartRate != nil })?.restingHeartRate {
                    LabeledContent("Resting heart rate", value: "\(hr) bpm")
                }
                if let waist = vitals.first(where: { $0.waistCm != nil })?.waistCm {
                    LabeledContent("Waist", value: units.lengthString(cm: waist))
                }
                if let sleep = vitals.first(where: { $0.sleepHours != nil })?.sleepHours {
                    LabeledContent("Sleep", value: String(format: "%.1f h", sleep))
                }
                if vitals.isEmpty {
                    Text("No vitals yet. Log blood pressure, measurements or sleep to see trends.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
            }
            .font(.subheadline)
        }
        .buttonStyle(.plain)
        .tappableCard()
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
            Text(tip)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Actions

    private func addWater() {
        context.insertWater(WaterEntry(date: .now, amountMl: units.glassMl))
        try? context.save()
    }

    private func removeWater() {
        guard let last = todaysWater.sorted(by: { $0.date < $1.date }).last else { return }
        context.deleteWater(last)
        try? context.save()
    }
}

struct QuickActionButton: View {
    var title: String
    var systemImage: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.15), in: Circle())
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}

extension MealType {
    var order: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .dinner: return 2
        case .snack: return 3
        }
    }
}

/// Haptics follow the data rather than the buttons, so they fire however an entry
/// was added. The system's own haptics setting still applies.
struct TodayHaptics: ViewModifier {
    var foodCount: Int
    var weighIns: Int
    var waterMl: Double
    var waterGoalMl: Double
    var streak: Int

    private var waterGoalReached: Bool { waterMl >= waterGoalMl }

    func body(content: Content) -> some View {
        // Named conditions with concrete types: inline closures here overwhelm the type checker.
        content
            .sensoryFeedback(SensoryFeedback.success, trigger: foodCount, condition: Self.grew)
            .sensoryFeedback(SensoryFeedback.success, trigger: weighIns, condition: Self.grew)
            .sensoryFeedback(SensoryFeedback.impact(weight: .light), trigger: waterMl, condition: Self.rose)
            .sensoryFeedback(SensoryFeedback.success, trigger: waterGoalReached, condition: Self.becameTrue)
            .sensoryFeedback(SensoryFeedback.levelChange, trigger: streak, condition: Self.grew)
    }

    private static func grew(_ old: Int, _ new: Int) -> Bool { new > old }
    private static func rose(_ old: Double, _ new: Double) -> Bool { new > old }
    private static func becameTrue(_ old: Bool, _ new: Bool) -> Bool { !old && new }
}
