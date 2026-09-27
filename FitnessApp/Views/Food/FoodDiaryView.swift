import SwiftUI
import SwiftData
import TipKit
import UIKit

struct FoodDiaryView: View {
    @State private var date = Date.now
    @State private var showCalendar = false

    var body: some View {
        NavigationStack {
            DayDiaryView(date: date.startOfDay)
                .id(date.startOfDay)
                .transition(.opacity)
                // Rows keep their own swipe-to-delete; a horizontal swipe elsewhere changes day.
                .gesture(DragGesture(minimumDistance: 40).onEnded(swiped))
                .safeAreaInset(edge: .top) {
                    DayStepper(date: $date)
                        .padding(.vertical, 8)
                        .background(.bar)
                }
                .navigationTitle("Food")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showCalendar = true } label: {
                            Image(systemName: "calendar")
                        }
                        .accessibilityLabel("Choose a day")
                    }
                }
                .sheet(isPresented: $showCalendar) {
                    DiaryCalendarSheet(date: $date)
                }
        }
    }

    private func swiped(_ value: DragGesture.Value) {
        let dx = value.translation.width
        guard abs(dx) > 80, abs(dx) > abs(value.translation.height) * 2 else { return }
        if dx > 0 {
            withAnimation { date = date.adding(days: -1) }
        } else if !date.isToday {
            withAnimation { date = date.adding(days: 1) }
        }
    }
}

/// A month calendar that marks days with diary entries.
struct DiaryCalendarSheet: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [FoodLogEntry]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                LoggedDaysCalendar(selection: $date,
                                   loggedDays: Set(entries.map { Calendar.current.startOfDay(for: $0.date) }),
                                   onSelect: { dismiss() })
                Label("Days with food logged", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .labelStyle(DotLabelStyle())
                    .padding(.horizontal)
                Spacer()
            }
            .navigationTitle("Choose a day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Today") { date = .now; dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct DotLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Color.accentColor).frame(width: 6, height: 6)
            configuration.title
        }
    }
}

/// UICalendarView, because SwiftUI's DatePicker can't decorate individual days.
struct LoggedDaysCalendar: UIViewRepresentable {
    @Binding var selection: Date
    var loggedDays: Set<Date>
    var onSelect: () -> Void

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = .current
        view.availableDateRange = DateInterval(start: .distantPast, end: .now)
        view.delegate = context.coordinator
        let single = UICalendarSelectionSingleDate(delegate: context.coordinator)
        single.selectedDate = Calendar.current.dateComponents([.year, .month, .day], from: selection)
        view.selectionBehavior = single
        view.visibleDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: selection)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UICalendarView, context: Context) {
        let changed = context.coordinator.loggedDays != loggedDays
        context.coordinator.parent = self
        context.coordinator.loggedDays = loggedDays
        if changed {
            let visible = Calendar.current.dateComponents([.year, .month], from: selection)
            let days = loggedDays.map { Calendar.current.dateComponents([.year, .month, .day], from: $0) }
                .filter { $0.year == visible.year && $0.month == visible.month }
            view.reloadDecorations(forDateComponents: days, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: LoggedDaysCalendar
        var loggedDays: Set<Date>

        init(parent: LoggedDaysCalendar) {
            self.parent = parent
            self.loggedDays = parent.loggedDays
        }

        func calendarView(_ calendarView: UICalendarView,
                          decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let date = Calendar.current.date(from: dateComponents),
                  loggedDays.contains(Calendar.current.startOfDay(for: date)) else { return nil }
            return .default(color: .tintColor, size: .small)
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let components = dateComponents, let date = Calendar.current.date(from: components) else { return }
            parent.selection = date
            parent.onSelect()
        }
    }
}

struct DayDiaryView: View {
    let date: Date

    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter
    @Query private var entries: [FoodLogEntry]
    @Query private var yesterdayEntries: [FoodLogEntry]
    @Query private var earlierThisWeek: [FoodLogEntry]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]

    @State private var addingTo: MealType?
    @State private var editing: FoodLogEntry?
    @State private var savingFavourite: MealType?
    @ScaledMetric(relativeTo: .headline) private var ringSize: CGFloat = 84

    init(date: Date) {
        self.date = date
        let start = date.startOfDay
        let end = start.adding(days: 1)
        let yesterday = start.adding(days: -1)
        _entries = Query(filter: #Predicate<FoodLogEntry> { $0.date >= start && $0.date < end },
                         sort: \FoodLogEntry.date)
        _yesterdayEntries = Query(filter: #Predicate<FoodLogEntry> { $0.date >= yesterday && $0.date < start },
                                  sort: \FoodLogEntry.date)
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        _earlierThisWeek = Query(filter: #Predicate<FoodLogEntry> { $0.date >= weekStart && $0.date < start })
    }

    private var currentKg: Double { weights.first?.weightKg ?? profile.startWeightKg }
    private var target: Int {
        let daily = profile.calorieTarget(currentWeightKg: currentKg)
        guard date.isToday else { return daily }
        var base = daily
        if profile.weeklyBudgetEnabled, !profile.isOnDietBreak, !profile.isMaintaining, profile.customCalorieTarget == nil {
            var byDay: [Date: Double] = [:]
            for e in earlierThisWeek { byDay[e.date.startOfDay, default: 0] += e.calories }
            base = BudgetCalculator.weeklyAdjustedTarget(dailyTarget: daily, intakeByDay: byDay,
                                                         floor: NutritionCalculator.calorieFloor(for: profile.sex))
        }
        return base + HealthKitManager.shared.activeEnergyCredit
    }
    private var macroTargets: MacroTargets { profile.macroTargets(currentWeightKg: currentKg) }

    private var consumed: Double { entries.reduce(0) { $0 + $1.calories } }
    private var protein: Double { entries.reduce(0) { $0 + $1.protein } }
    private var carbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    private var fat: Double { entries.reduce(0) { $0 + $1.fat } }

    private func entries(for meal: MealType) -> [FoodLogEntry] {
        entries.filter { $0.mealType == meal }
    }

    private func yesterday(for meal: MealType) -> [FoodLogEntry] {
        yesterdayEntries.filter { $0.mealType == meal }
    }

    /// Re-logs yesterday's lines for this meal onto the current day.
    /// Some meal is still empty today but was logged yesterday.
    private var canCopyFromYesterday: Bool {
        MealType.allCases.contains { entries(for: $0).isEmpty && !yesterday(for: $0).isEmpty }
    }

    private func copyYesterday(_ meal: MealType) {
        CopyYesterdayTip().invalidate(reason: .actionPerformed)
        let stamp = meal.logDate(on: date)
        for e in yesterday(for: meal) {
            context.insertDiaryEntry(FoodLogEntry(date: stamp, mealType: meal, foodName: e.foodName, servings: e.servings,
                                        servingDescription: e.servingDescription, calories: e.calories,
                                        protein: e.protein, carbs: e.carbs, fat: e.fat, foodItemID: e.foodItemID,
                                        fiber: e.fiber, sugar: e.sugar, sodium: e.sodium))
        }
        try? context.save()
    }

    private func clear(_ meal: MealType) {
        context.deleteDiaryEntries(entries(for: meal), undo: undoCenter)
    }

    var body: some View {
        List {
            Section {
                summary
            }
            if date.isToday, canCopyFromYesterday {
                Section { TipView(CopyYesterdayTip()) }
            }
            if entries.isEmpty {
                let meal = MealType.current()
                let cal = Calendar.current
                let when = cal.isDateInToday(date) || cal.isDateInYesterday(date)
                    ? date.relativeDayLabel.lowercased() : "on \(date.relativeDayLabel)"
                Section {
                    ContentUnavailableView {
                        Label("Nothing logged \(when)", systemImage: "fork.knife")
                    } description: {
                        Text("Log what you eat to see calories and macros against your target.")
                    } actions: {
                        Button("Log \(meal.label.lowercased())") { addingTo = meal }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            ForEach(MealType.allCases) { meal in
                let items = entries(for: meal)
                Section {
                    ForEach(items) { entry in
                        Button { editing = entry } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.foodName).foregroundStyle(Color.primary)
                                    Text(entry.servingsLabel).font(.caption).foregroundStyle(Color.secondary)
                                }
                                Spacer()
                                Text("\(Int(entry.calories.rounded()))")
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        context.deleteDiaryEntries(offsets.map { items[$0] }, undo: undoCenter)
                    }
                    Button {
                        addingTo = meal
                    } label: {
                        Label("Add food", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    let fromYesterday = yesterday(for: meal)
                    if items.isEmpty, !fromYesterday.isEmpty {
                        let kcal = fromYesterday.reduce(0) { $0 + $1.calories }
                        Button {
                            copyYesterday(meal)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Copy yesterday's \(meal.label.lowercased())")
                                        .font(.subheadline.weight(.medium))
                                    Text("\(fromYesterday.count) item\(fromYesterday.count == 1 ? "" : "s") · \(Int(kcal.rounded())) kcal")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                            } icon: {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Label(meal.label, systemImage: meal.systemImage)
                        Spacer()
                        let kcal = items.reduce(0) { $0 + $1.calories }
                        if kcal > 0 {
                            Text("\(Int(kcal.rounded())) kcal")
                        }
                        Menu {
                            Button {
                                copyYesterday(meal)
                            } label: {
                                Label("Copy from yesterday", systemImage: "arrow.uturn.backward")
                            }
                            .disabled(yesterday(for: meal).isEmpty)
                            Button {
                                savingFavourite = meal
                            } label: {
                                Label("Save as favourite meal", systemImage: "star")
                            }
                            .disabled(items.isEmpty)
                            if !items.isEmpty {
                                Button(role: .destructive) {
                                    clear(meal)
                                } label: {
                                    Label("Clear \(meal.label.lowercased())", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.body)
                                .accessibilityLabel("\(meal.label) options")
                        }
                        .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $addingTo) { meal in
            FoodSearchView(date: date, mealType: meal)
        }
        .sheet(item: $editing) { entry in
            EditLogEntrySheet(entry: entry)
        }
        .sheet(item: $savingFavourite) { meal in
            SaveFavouriteMealSheet(mealType: meal, entries: entries(for: meal))
        }
        .sensoryFeedback(.success, trigger: entries.count) { old, new in new > old }
    }

    private var summary: some View {
        VStack(spacing: 12) {
            AdaptiveStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: target > 0 ? consumed / Double(target) : 0, lineWidth: 10)
                    VStack(spacing: 0) {
                        Text("\(Int(consumed.rounded()))")
                            .font(.headline.monospacedDigit())
                            .minimumScaleFactor(0.5)
                        Text("of \(target)")
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                            .minimumScaleFactor(0.5)
                    }
                    .lineLimit(1)
                    .padding(10)
                }
                .frame(width: ringSize, height: ringSize)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Calories")
                .accessibilityValue("\(Int(consumed.rounded())) of \(target)")
                VStack(spacing: 8) {
                    MacroBar(name: "Protein", consumed: protein, target: macroTargets.protein, color: .blue)
                    MacroBar(name: "Carbs", consumed: carbs, target: macroTargets.carbs, color: .orange)
                    MacroBar(name: "Fat", consumed: fat, target: macroTargets.fat, color: .pink)
                }
            }
            NutrientRow(fiber: entries.reduce(0) { $0 + $1.fiber },
                        sugar: entries.reduce(0) { $0 + $1.sugar },
                        sodium: entries.reduce(0) { $0 + $1.sodium },
                        profile: profile)
            let remaining = Double(target) - consumed
            Text(remaining >= 0 ? "\(Int(remaining.rounded())) kcal remaining" : "\(Int((-remaining).rounded())) kcal over budget")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(remaining >= 0 ? Color.primary : Color.orange)
        }
        .padding(.vertical, 4)
    }
}

struct EditLogEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter
    @Environment(\.dismiss) private var dismiss
    let entry: FoodLogEntry

    @State private var servings: Double = 1
    @State private var meal: MealType = .snack
    @State private var loaded = false

    private var perServing: (kcal: Double, p: Double, c: Double, f: Double) {
        let s = max(entry.servings, 0.01)
        return (entry.calories / s, entry.protein / s, entry.carbs / s, entry.fat / s)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(entry.foodName) {
                    Picker("Meal", selection: $meal) {
                        ForEach(MealType.allCases) { Text($0.label).tag($0) }
                    }
                    ServingsControl(servings: $servings, description: entry.servingDescription)
                    LabeledContent("Calories", value: "\(Int((perServing.kcal * servings).rounded())) kcal")
                    MacroSummary(protein: perServing.p * servings, carbs: perServing.c * servings, fat: perServing.f * servings)
                }
                Section {
                    Button("Delete entry", role: .destructive) {
                        context.deleteDiaryEntries([entry], undo: undoCenter)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let p = perServing
                        let ratio = servings / max(entry.servings, 0.01)
                        entry.fiber *= ratio
                        entry.sugar *= ratio
                        entry.sodium *= ratio
                        entry.servings = servings
                        entry.calories = p.kcal * servings
                        entry.protein = p.p * servings
                        entry.carbs = p.c * servings
                        entry.fat = p.f * servings
                        entry.mealType = meal
                        try? context.save()
                        HealthKitManager.shared.recordDiaryEntry(entry)
                        dismiss()
                    }
                    .disabled(servings <= 0)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                servings = entry.servings
                meal = entry.mealType
            }
        }
        .presentationDetents([.medium])
    }
}

struct ServingsControl: View {
    @Binding var servings: Double
    var description: String
    /// Grams or millilitres per serving, when known, to allow entering the weight directly.
    var metric: GroceryAggregator.Quantity? = nil
    /// Household measures for this food; replaces the generic multiples when present.
    var presets: [ServingPreset] = []

    @State private var byWeight = false

    private let multiples: [Double] = [0.5, 1, 1.5, 2, 3]

    private func weightBinding(_ metric: GroceryAggregator.Quantity) -> Binding<Double> {
        Binding(get: { ServingUnits.metric(forServings: servings, per: metric) },
                set: { servings = ServingUnits.servings(forMetric: $0, per: metric) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let metric {
                Picker("Amount in", selection: $byWeight) {
                    Text("Servings").tag(false)
                    Text(metric.unit).tag(true)
                }
                .pickerStyle(.segmented)
            }
            if byWeight, let metric {
                HStack {
                    Text(metric.unit == "g" ? "Weight" : "Volume")
                    Spacer()
                    TextField(metric.unit, value: weightBinding(metric), format: .number.precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                    Text(metric.unit).foregroundStyle(Color.secondary)
                }
                Text("= \(servings.formatted(.number.precision(.fractionLength(0...2)))) servings")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            } else {
                HStack {
                    Text("Servings")
                    Spacer()
                    TextField("Servings", value: $servings, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                    Stepper("", value: $servings, in: 0.25...50, step: 0.25).labelsHidden()
                }
                if !description.isEmpty {
                    Text("1 serving = \(description)")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    if presets.isEmpty {
                        ForEach(multiples, id: \.self) { value in
                            chip(value.cleanString, value: value)
                        }
                    } else {
                        chip("1 serving", value: 1)
                        ForEach(presets) { preset in
                            chip(preset.label, value: preset.servings)
                        }
                    }
                }
            }
        }
    }

    private func chip(_ label: String, value: Double) -> some View {
        Button(label) { servings = value }
            .buttonStyle(.bordered)
            .tint(servings == value ? Color.accentColor : Color.secondary)
            .controlSize(.small)
    }
}

/// Names a set of diary lines and stores them as a `SavedMeal`.
struct SaveFavouriteMealSheet: View {
    let mealType: MealType
    let entries: [FoodLogEntry]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    private var totalCalories: Double { entries.reduce(0) { $0 + $1.calories } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Weekday breakfast)", text: $name)
                } footer: {
                    Text("Favourite meals appear at the top of food search and log every line with one tap.")
                }
                Section("\(entries.count) item\(entries.count == 1 ? "" : "s") · \(Int(totalCalories.rounded())) kcal") {
                    ForEach(entries) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.foodName)
                                Text(e.servingsLabel).font(.caption).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Text("\(Int(e.calories.rounded()))")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Save favourite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let meal = SavedMeal(name: name.trimmingCharacters(in: .whitespaces),
                                             mealType: mealType,
                                             items: entries.map(SavedMealItem.init(entry:)))
                        context.insert(meal)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || entries.isEmpty)
                }
            }
            .onAppear {
                if name.isEmpty {
                    name = "\(mealType.label) · \(Date.now.formatted(.dateTime.weekday(.abbreviated)))"
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
