import SwiftUI
import SwiftData
import TipKit
import UIKit

struct FoodDiaryView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var date = Date.now
    @State private var showCalendar = false
    /// The diary day per window, restored on relaunch (SceneStorage can't hold a Date).
    @SceneStorage("diaryDay") private var storedDay: Double = 0

    var body: some View {
        NavigationStack {
            Group {
                if sizeClass == .regular {
                    // iPad: the month calendar stays beside the selected day.
                    HStack(spacing: 0) {
                        DiaryCalendarPane(date: $date)
                            .frame(width: 360)
                        Divider()
                        day
                    }
                } else {
                    day
                }
            }
            .navigationTitle("Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if sizeClass != .regular {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showCalendar = true } label: {
                            Image(systemName: "calendar")
                        }
                        .accessibilityLabel("Choose a day")
                    }
                }
            }
            .sheet(isPresented: $showCalendar) {
                DiaryCalendarSheet(date: $date)
            }
            .onAppear {
                if storedDay > 0 { date = DiaryDayRestore.day(stored: storedDay) }
            }
            .onChange(of: date) { _, day in storedDay = DiaryDayRestore.stored(day) }
            .focusedSceneValue(\.diaryDayActions, DiaryDayActions(
                previous: { withAnimation { date = date.adding(days: -1) } },
                next: date.isToday ? nil : { withAnimation { date = date.adding(days: 1) } }))
        }
    }

    private var day: some View {
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

/// The month calendar shown beside the diary on iPad.
struct DiaryCalendarPane: View {
    @Binding var date: Date
    @Query private var entries: [FoodLogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LoggedDaysCalendar(selection: $date,
                               loggedDays: Set(entries.map { Calendar.current.startOfDay(for: $0.date) }),
                               onSelect: {})
            Label("Days with food logged", systemImage: "circle.fill")
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .labelStyle(DotLabelStyle())
                .padding(.horizontal)
            if !date.isToday {
                Button("Back to today") { date = .now }
                    .padding(.horizontal)
            }
            Spacer()
        }
        .padding(.top, 8)
        .background(Color(.systemGroupedBackground))
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
        // Follow a selection changed elsewhere (the day stepper beside it on iPad).
        let wanted = Calendar.current.dateComponents([.year, .month, .day], from: selection)
        if let single = view.selectionBehavior as? UICalendarSelectionSingleDate,
           single.selectedDate?.year != wanted.year || single.selectedDate?.month != wanted.month
            || single.selectedDate?.day != wanted.day {
            single.setSelected(wanted, animated: true)
            view.setVisibleDateComponents(wanted, animated: true)
        }
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
    @AppStorage(ExtraNutrients.storageKey) private var showExtraNutrients = false
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter
    @Query private var entries: [FoodLogEntry]
    @Query private var yesterdayEntries: [FoodLogEntry]
    @Query private var exercise: [ExerciseEntry]
    @Query private var earlierThisWeek: [FoodLogEntry]
    /// The weeks before this day, for "Log again".
    @Query private var history: [FoodLogEntry]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]

    @State private var addingTo: MealType?
    @State private var editing: FoodLogEntry?
    @State private var relocating: Relocation?
    @State private var savingFavourite: MealType?
    @State private var photographing: MealType?
    @State private var editMode: EditMode = .inactive
    @State private var selection: Set<PersistentIdentifier> = []
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
        _exercise = Query(filter: #Predicate<ExerciseEntry> { $0.date >= start && $0.date < end })
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        _earlierThisWeek = Query(filter: #Predicate<FoodLogEntry> { $0.date >= weekStart && $0.date < start })
        let lookback = start.adding(days: -RecentFoods.lookbackDays)
        _history = Query(filter: #Predicate<FoodLogEntry> { $0.date >= lookback && $0.date < start },
                         sort: \FoodLogEntry.date, order: .reverse)
    }

    private var isSelecting: Bool { editMode.isEditing }

    private var selectedEntries: [FoodLogEntry] {
        entries.filter { selection.contains($0.persistentModelID) }
    }

    private func endSelecting() {
        withAnimation {
            editMode = .inactive
            selection = []
        }
    }

    /// Foods eaten in this meal on earlier days, offered as one-tap "Log again" chips.
    private func logAgainOptions(for meal: MealType) -> [FoodLogEntry] {
        let pool = history.filter { $0.mealType == meal && !$0.isEstimate }
        let keys = RecentFoods.suggestions(history: pool.map(\.recentLine), meal: meal,
                                           alreadyLogged: Set(entries(for: meal).map(\.recentKey)))
        var latest: [String: FoodLogEntry] = [:]
        for entry in pool where latest[entry.recentKey] == nil { latest[entry.recentKey] = entry }
        return keys.compactMap { latest[$0] }
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
        return base + ExerciseCatalog.combinedCredit(
            health: HealthKitManager.shared.activeEnergyCredit,
            exercise: ExerciseCatalog.earnBack(exerciseKcal: exercise.reduce(0) { $0 + $1.calories },
                                               percent: ExerciseSettings.earnBackPercent))
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
                                        fiber: e.fiber, sugar: e.sugar, sodium: e.sodium).withExtras(from: e))
        }
        try? context.save()
    }

    /// Move or copy a diary line: other meals today, tomorrow, or any day.
    @ViewBuilder
    private func relocateMenu(_ entry: FoodLogEntry) -> some View {
        Menu {
            ForEach(MealType.allCases.filter { $0 != entry.mealType }) { meal in
                Button(meal.label) { context.moveDiaryEntry(entry, to: meal, on: date, undo: undoCenter) }
            }
            Divider()
            Button("Another day…") { relocating = Relocation(entries: [entry], copying: false) }
        } label: {
            Label("Move to", systemImage: "arrow.right.circle")
        }
        Menu {
            ForEach(MealType.allCases) { meal in
                Button(meal.label) { context.copyDiaryEntry(entry, to: meal, on: date, undo: undoCenter) }
            }
            Divider()
            Button("Tomorrow") {
                context.copyDiaryEntry(entry, to: entry.mealType, on: date.adding(days: 1), undo: undoCenter)
            }
            Button("Another day…") { relocating = Relocation(entries: [entry], copying: true) }
        } label: {
            Label("Copy to", systemImage: "doc.on.doc")
        }
    }

    /// Changes an entry's servings from its row, with undo.
    private func setServings(_ entry: FoodLogEntry, to servings: Double) {
        let previous = entry.servings
        guard servings != previous else { return }
        entry.scale(toServings: servings)
        try? context.save()
        HealthKitManager.shared.recordDiaryEntry(entry)
        undoCenter.offer(String(localized: "Changed \(entry.foodName) to \(servings.cleanString) servings")) {
            entry.scale(toServings: previous)
            try? context.save()
            HealthKitManager.shared.recordDiaryEntry(entry)
        }
    }

    private func clear(_ meal: MealType) {
        context.deleteDiaryEntries(entries(for: meal), undo: undoCenter)
    }

    var body: some View {
        List(selection: $selection) {
            Section {
                summary
            }
            if date.isToday, canCopyFromYesterday, !isSelecting {
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
                        Button("Log \(meal.inSentence)") { addingTo = meal }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            ForEach(MealType.allCases) { meal in
                let items = entries(for: meal)
                Section {
                    ForEach(items) { entry in
                        entryRow(entry)
                            .tag(entry.persistentModelID)
                    }
                    .onDelete { offsets in
                        context.deleteDiaryEntries(offsets.map { items[$0] }, undo: undoCenter)
                    }
                    if !isSelecting {
                        mealActions(meal, items: items)
                    }
                } header: {
                    mealHeader(meal, items: items)
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .toolbar { selectionToolbar }
        .onChange(of: entries.isEmpty) { _, empty in
            if empty { endSelecting() }
        }
        .sheet(item: $addingTo) { meal in
            FoodSearchView(date: date, mealType: meal)
        }
        .sheet(item: $relocating) { relocation in
            RelocateEntrySheet(entries: relocation.entries, copying: relocation.copying) { meal, day in
                if relocation.copying {
                    context.copyDiaryEntries(relocation.entries, to: meal, on: day, undo: undoCenter)
                } else {
                    context.moveDiaryEntries(relocation.entries, to: meal, on: day, undo: undoCenter)
                }
                endSelecting()
            }
        }
        .sheet(item: $editing) { entry in
            if entry.photo != nil || entry.isEstimate {
                PhotoMealDetailSheet(entry: entry)
            } else {
                EditLogEntrySheet(entry: entry)
            }
        }
        .sheet(item: $photographing) { meal in
            PhotoMealSheet(date: date, mealType: meal, dailyTarget: profile.calorieTarget(currentWeightKg: currentKg))
        }
        .sheet(item: $savingFavourite) { meal in
            SaveFavouriteMealSheet(mealType: meal, entries: entries(for: meal))
        }
        .sensoryFeedback(.success, trigger: entries.count) { old, new in new > old }
    }

    /// A diary line: tap to edit, with an inline servings menu. Plain while selecting,
    /// so a tap selects the row instead.
    @ViewBuilder
    private func entryRow(_ entry: FoodLogEntry) -> some View {
        let content = HStack {
            if let photo = entry.photo { EntryThumbnail(data: photo) }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodName).foregroundStyle(Color.primary)
                Text(entry.isEstimate ? "Estimate · tap to fill in" : entry.servingsLabel)
                    .font(.caption)
                    .foregroundStyle(entry.isEstimate ? Color.orange : Color.secondary)
            }
            Spacer()
        }
        let kcal = Text("\(Int(entry.calories.rounded()))")
            .font(.body.monospacedDigit())
            .foregroundStyle(Color.secondary)
        if isSelecting {
            HStack {
                content
                kcal
            }
        } else {
            HStack {
                Button { editing = entry } label: {
                    content.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if !entry.isEstimate {
                    ServingsMenu(servings: entry.servings) { setServings(entry, to: $0) }
                }
                kcal
            }
            .contextMenu { relocateMenu(entry) }
            .draggable(FoodReference(entry: entry))
        }
    }

    /// Add food, photo, copy-yesterday and "Log again" rows under a meal's entries.
    @ViewBuilder
    private func mealActions(_ meal: MealType, items: [FoodLogEntry]) -> some View {
        HStack {
            Button {
                addingTo = meal
            } label: {
                Label("Add food", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderless)
            .foodDropDestination { references in
                references.map { $0.log(on: date, as: meal, context: context, undo: undoCenter) }.contains(true)
            }
            Spacer()
            Button {
                photographing = meal
            } label: {
                Label("Photo", systemImage: "camera")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Log \(meal.inSentence) from a photo")
        }
        let fromYesterday = yesterday(for: meal)
        if items.isEmpty, !fromYesterday.isEmpty {
            let kcal = fromYesterday.reduce(0) { $0 + $1.calories }
            Button {
                copyYesterday(meal)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Copy yesterday's \(meal.inSentence)")
                            .font(.subheadline.weight(.medium))
                        Text("\(fromYesterday.count) items · \(Energy.string(kcal))")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                } icon: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                }
            }
        }
        let again = logAgainOptions(for: meal)
        if !again.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Log again")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .accessibilityHidden(true)
                    ForEach(again) { entry in
                        Button {
                            context.logAgain(entry, to: meal, on: date, undo: undoCenter)
                        } label: {
                            Label(entry.foodName, systemImage: "plus")
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel("Log \(entry.foodName) again")
                        .accessibilityHint(entry.servingsLabel)
                    }
                }
            }
        }
    }

    private func mealHeader(_ meal: MealType, items: [FoodLogEntry]) -> some View {
        HStack {
            Label(meal.label, systemImage: meal.systemImage)
            Spacer()
            let kcal = items.reduce(0) { $0 + $1.calories }
            if kcal > 0 {
                Text("\(Energy.string(kcal))")
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
                        Label("Clear \(meal.inSentence)", systemImage: "trash")
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

    @ToolbarContentBuilder
    private var selectionToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isSelecting {
                Button("Done") { endSelecting() }
            } else if !entries.isEmpty {
                Button("Select") { withAnimation { editMode = .active } }
            }
        }
        if isSelecting {
            ToolbarItemGroup(placement: .bottomBar) {
                let chosen = selectedEntries
                Menu {
                    ForEach(MealType.allCases) { meal in
                        Button(meal.label) {
                            context.moveDiaryEntries(chosen, to: meal, on: date, undo: undoCenter)
                            endSelecting()
                        }
                    }
                    Divider()
                    Button("Another day…") { relocating = Relocation(entries: chosen, copying: false) }
                } label: {
                    Label("Move to", systemImage: "arrow.right.circle")
                }
                .disabled(chosen.isEmpty)
                Spacer()
                Menu {
                    ForEach(MealType.allCases) { meal in
                        Button(meal.label) {
                            context.copyDiaryEntries(chosen, to: meal, on: date, undo: undoCenter)
                            endSelecting()
                        }
                    }
                    Divider()
                    Button("Another day…") { relocating = Relocation(entries: chosen, copying: true) }
                } label: {
                    Label("Copy to", systemImage: "doc.on.doc")
                }
                .disabled(chosen.isEmpty)
                Spacer()
                Text(chosen.isEmpty ? "Select entries" : "\(chosen.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                Spacer()
                Button(role: .destructive) {
                    context.deleteDiaryEntries(chosen, undo: undoCenter)
                    endSelecting()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(chosen.isEmpty)
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 12) {
            AdaptiveStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: target > 0 ? consumed / Double(target) : 0, lineWidth: 10)
                    VStack(spacing: 0) {
                        Text(Energy.number(consumed))
                            .font(.headline.monospacedDigit())
                            .minimumScaleFactor(0.5)
                        Text("of \(Energy.string(target))")
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
            if showExtraNutrients {
                ExtraNutrientRow(saturatedFat: entries.reduce(0) { $0 + $1.saturatedFat },
                                 potassium: entries.reduce(0) { $0 + $1.potassium },
                                 cholesterol: entries.reduce(0) { $0 + $1.cholesterol },
                                 profile: profile)
            }
            let remaining = Double(target) - consumed
            Text(remaining >= 0 ? "\(Energy.string(remaining)) remaining" : "\(Energy.string((-remaining))) over budget")
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
                    LabeledContent("Calories", value: "\(Energy.string((perServing.kcal * servings)))")
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
                        entry.scale(toServings: servings)
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
    @State private var photo: Data?

    private var totalCalories: Double { entries.reduce(0) { $0 + $1.calories } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Weekday breakfast)", text: $name)
                } footer: {
                    Text("Favourite meals appear at the top of food search and log every line with one tap.")
                }
                MealPhotoSection(photo: $photo)
                Section("\(entries.count) items · \(Energy.string(totalCalories))") {
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
                        meal.photo = photo
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
                    photo = SavedMeal.firstPhoto(in: entries)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

enum DiaryDayRestore {
    /// What to keep for a window: nothing (0) for today, so a relaunch the next morning opens
    /// on that day rather than yesterday. Only a day picked on purpose is kept.
    static func stored(_ day: Date, now: Date = .now, calendar: Calendar = .current) -> Double {
        calendar.isDate(day, inSameDayAs: now) ? 0 : day.timeIntervalSinceReferenceDate
    }

    /// A restored diary day, unless it's in the future (the clock changed) — then today.
    static func day(stored: Double, now: Date = .now) -> Date {
        let day = Date(timeIntervalSinceReferenceDate: stored)
        return day > now ? now : day
    }
}

/// A compact servings picker shown in a diary row.
struct ServingsMenu: View {
    var servings: Double
    var onChange: (Double) -> Void

    private static let choices: [Double] = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4]

    var body: some View {
        Menu {
            Picker("Servings", selection: Binding(get: { servings }, set: onChange)) {
                ForEach(Self.choices.contains(servings) ? Self.choices : (Self.choices + [servings]).sorted(),
                        id: \.self) { value in
                    Text("\(value.cleanString)×").tag(value)
                }
            }
            Divider()
            Button { onChange(servings + 0.5) } label: { Label("Add half a serving", systemImage: "plus") }
            if servings > 0.5 {
                Button { onChange(servings - 0.5) } label: { Label("Remove half a serving", systemImage: "minus") }
            }
        } label: {
            Text("\(servings.cleanString)×")
                .font(.caption.monospacedDigit().weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .accessibilityLabel("Servings")
        .accessibilityValue(servings.cleanString)
        .accessibilityIdentifier("servingsMenu")
    }
}

/// Diary lines waiting for a day and meal to be moved or copied to.
struct Relocation: Identifiable {
    let id = UUID()
    let entries: [FoodLogEntry]
    let copying: Bool
}

/// Pick a day and meal to move or copy diary lines to.
struct RelocateEntrySheet: View {
    let entries: [FoodLogEntry]
    let copying: Bool
    var perform: (MealType, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var day = Date.now
    @State private var meal: MealType = .snack

    var body: some View {
        NavigationStack {
            Form {
                Section(entries.count == 1 ? entries[0].foodName : String(localized: "\(entries.count) entries")) {
                    DatePicker("Day", selection: $day, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    Picker("Meal", selection: $meal) {
                        ForEach(MealType.allCases) { Text($0.label).tag($0) }
                    }
                }
            }
            .navigationTitle(copying ? "Copy to" : "Move to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(copying ? "Copy" : "Move") {
                        perform(meal, day.startOfDay)
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard let first = entries.first else { return }
                day = first.date
                meal = first.mealType
            }
        }
    }
}
