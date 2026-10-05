import SwiftUI
import SwiftData

/// Rate hunger before a meal and mood after it.
struct MealCheckInSheet: View {
    let day: Date
    let mealType: MealType
    let existing: MealCheckIn?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var hunger: Int?
    @State private var mood: Int?
    @State private var loaded = false

    static func summary(_ checkIn: MealCheckIn) -> String {
        var parts: [String] = []
        if let hunger = checkIn.hunger { parts.append(String(localized: "Hunger: \(MealRating.hungerLabel(hunger))")) }
        if let mood = checkIn.mood { parts.append(String(localized: "Mood: \(MealRating.moodLabel(mood))")) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ratingPicker("Hunger before", selection: $hunger, label: MealRating.hungerLabel)
                } footer: {
                    Text("How hungry you were before eating.")
                }
                Section {
                    ratingPicker("Mood after", selection: $mood, label: MealRating.moodLabel)
                } footer: {
                    Text("How you felt afterwards. Patterns show up under Vitals → Patterns once you've rated a couple of weeks.")
                }
            }
            .navigationTitle(mealType.label)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                hunger = existing?.hunger
                mood = existing?.mood
            }
        }
        .presentationDetents([.medium])
    }

    private func ratingPicker(_ title: LocalizedStringKey, selection: Binding<Int?>,
                              label: @escaping (Int) -> String) -> some View {
        Picker(title, selection: selection) {
            Text("Not rated").tag(Int?.none)
            ForEach(MealRating.range, id: \.self) { value in
                Text("\(value) · \(label(value))").tag(Int?.some(value))
            }
        }
    }

    private func save() {
        if let existing {
            existing.hunger = hunger
            existing.mood = mood
            if hunger == nil && mood == nil { context.delete(existing) }
        } else if hunger != nil || mood != nil {
            context.insert(MealCheckIn(day: day, mealType: mealType, hunger: hunger, mood: mood))
        }
        try? context.save()
        dismiss()
    }
}
