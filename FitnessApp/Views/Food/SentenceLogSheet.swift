import SwiftUI
import SwiftData

/// Type or dictate what you ate, check the foods and amounts Stride found, then log them together.
struct SentenceLogSheet: View {
    let date: Date
    var onLogged: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]

    @State private var meal: MealType
    @State private var text = ""
    @State private var lines: [Line] = []
    @State private var choosingFor: Line.ID?
    @FocusState private var editing: Bool

    struct Line: Identifiable {
        let id = UUID()
        var item: FoodSentenceParser.Item
        var food: FoodItem?
        var servings: Double
        var included = true
    }

    init(date: Date, mealType: MealType, onLogged: @escaping () -> Void = {}) {
        self.date = date
        self.onLogged = onLogged
        _meal = State(initialValue: mealType)
    }

    private var toLog: [Line] { lines.filter { $0.included && $0.food != nil && $0.servings > 0 } }

    private var totalCalories: Double {
        toLog.reduce(0) { $0 + ($1.food?.calories ?? 0) * $1.servings }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("2 eggs, a slice of toast and a black coffee", text: $text, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($editing)
                        .submitLabel(.done)
                        .onSubmit(findFoods)
                        .accessibilityIdentifier("sentenceField")
                    Button("Find foods", action: findFoods)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("Separate foods with commas or “and”. You can dictate with the microphone on the keyboard.")
                }

                if !lines.isEmpty {
                    Section {
                        Picker("Meal", selection: $meal) {
                            ForEach(MealType.allCases) { Text($0.label).tag($0) }
                        }
                        ForEach($lines) { $line in
                            row($line)
                        }
                        .onDelete { lines.remove(atOffsets: $0) }
                    } header: {
                        Text("Found")
                    } footer: {
                        if !toLog.isEmpty {
                            Text("Total: \(Energy.string(totalCalories))")
                        }
                    }
                }
            }
            .navigationTitle("Describe what you ate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { log() }.disabled(toLog.isEmpty)
                }
            }
            .sheet(item: Binding(get: { choosingFor.flatMap { id in lines.first { $0.id == id } } },
                                 set: { choosingFor = $0?.id })) { line in
                FoodPickerSheet(initialQuery: line.item.name) { food in
                    guard let index = lines.firstIndex(where: { $0.id == line.id }) else { return }
                    lines[index].food = food
                    lines[index].servings = FoodSentenceParser.servings(for: line.item,
                                                                         servingDescription: food.servingDescription,
                                                                         presets: food.servingPresets)
                    lines[index].included = true
                }
            }
            .onAppear { editing = true }
        }
    }

    @ViewBuilder
    private func row(_ line: Binding<Line>) -> some View {
        let value = line.wrappedValue
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                if value.food != nil {
                    Toggle("Include", isOn: line.included)
                        .labelsHidden()
                        .toggleStyle(.checkmark)
                }
                Button { choosingFor = value.id } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(value.food?.displayName ?? value.item.name)
                            .foregroundStyle(value.food == nil ? Color.secondary : Color.primary)
                        Text(value.food == nil ? String(localized: "No match. Tap to search.")
                                               : String(localized: "From “\(value.item.name)”. Tap to change."))
                            .font(.caption)
                            .foregroundStyle(value.food == nil ? Color.orange : Color.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if let food = value.food {
                    Text(Energy.string(food.calories * value.servings))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.secondary)
                }
            }
            if let food = value.food {
                Stepper(value: line.servings, in: 0.25...50, step: 0.25) {
                    Text("\(value.servings.cleanString) × \(food.servingDescription)")
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .disabled(!value.included)
            }
        }
        .accessibilityIdentifier("sentenceLine")
    }

    private func findFoods() {
        editing = false
        lines = FoodSentenceParser.parse(text).map { item in
            let food = FoodSentenceParser.bestMatch(item.name, in: foods) {
                .init(name: $0.name, other: [$0.brand], isFavorite: $0.isFavorite, lastUsed: $0.lastUsed)
            }
            let servings = food.map {
                FoodSentenceParser.servings(for: item, servingDescription: $0.servingDescription, presets: $0.servingPresets)
            } ?? item.quantity
            return Line(item: item, food: food, servings: servings)
        }
    }

    private func log() {
        for line in toLog {
            line.food?.log(servings: line.servings, meal: meal, on: date, context: context)
        }
        try? context.save()
        dismiss()
        onLogged()
    }
}

/// Pick a saved food for a line that didn't match, starting from its words.
struct FoodPickerSheet: View {
    let initialQuery: String
    var onPick: (FoodItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @State private var search = ""

    private var results: [FoodItem] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return foods }
        return FoodSearchRanking.rank(foods, query: query) {
            .init(name: $0.name, other: [$0.brand, $0.barcode ?? ""], isFavorite: $0.isFavorite, lastUsed: $0.lastUsed)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty {
                    Text("No match for “\(search)”.")
                        .foregroundStyle(Color.secondary)
                }
                ForEach(results) { food in
                    Button {
                        onPick(food)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(food.displayName).foregroundStyle(Color.primary)
                                Text(food.servingDescription).font(.caption).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Text("\(Int(food.calories.rounded()))")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods")
            .navigationTitle("Choose a food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear { search = initialQuery }
        }
    }
}

private struct CheckmarkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(configuration.isOn ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(configuration.isOn ? Text("Included") : Text("Left out"))
    }
}

private extension ToggleStyle where Self == CheckmarkToggleStyle {
    static var checkmark: CheckmarkToggleStyle { CheckmarkToggleStyle() }
}
