import SwiftData
import SwiftUI

/// Rename, reorder, add and remove the meals in the diary, planner and reminders.
struct MealsEditor: View {
    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @State private var editing: MealSlot?
    @State private var isNew = false
    @State private var slots = MealSlots.shared.slots

    var body: some View {
        List {
            Section {
                ForEach(slots) { slot in
                    Button {
                        isNew = false
                        editing = slot
                    } label: {
                        HStack {
                            Label(slot.name, systemImage: slot.icon)
                            Spacer()
                            Text(Self.timeText(hour: slot.hour)).foregroundStyle(Color.secondary)
                        }
                    }
                    .foregroundStyle(Color.primary)
                    .accessibilityIdentifier("mealRow-\(slot.name)")
                }
                .onMove { source, destination in
                    slots.move(fromOffsets: source, toOffset: destination)
                    save()
                }
                .onDelete(perform: slots.count > 1 ? remove : nil)

                Button {
                    isNew = true
                    editing = MealSlot(id: MealSlots.newID(), name: "", icon: "fork.knife", hour: 12,
                                       reminds: false, share: MealSlots.newSlotShare)
                } label: {
                    Label("Add a meal", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("addMeal")
            } footer: {
                Text("Drag to reorder. At least one meal stays. Removing a meal moves its entries to the one before it. The usual time is used when you log to another day and for meal reminders.")
            }
            Section {
                Button("Reset to default meals") {
                    slots = MealSlots.defaults
                    save()
                }
                .disabled(slots == MealSlots.defaults)
            }
        }
        .diarySelectionMode(.constant(true))
        .navigationTitle("Meals")
        .inlineNavigationTitle()
        .strideSheet(item: $editing) { slot in
            MealSlotForm(slot: slot, isNew: isNew) { saved in
                if let index = slots.firstIndex(where: { $0.id == saved.id }) {
                    slots[index] = saved
                } else {
                    slots.append(saved)
                }
                save()
            }
        }
    }

    private func save() {
        let clean = MealSlots.sanitised(slots)
        slots = clean
        profile.mealSlotsJSON = clean == MealSlots.defaults ? "" : MealSlots.encode(clean)
        MealSlots.shared.slots = clean
        NotificationManager.sync(with: profile)
    }

    private func remove(at offsets: IndexSet) {
        guard slots.count > offsets.count else { return }
        for index in offsets.sorted(by: >) {
            let gone = slots[index]
            let heir = slots[index > 0 ? index - 1 : index + 1]
            Self.reassign(from: gone.id, to: heir.id, context: context)
            slots.remove(at: index)
        }
        save()
    }

    /// Moves everything filed under a removed meal to another one so nothing drops out of the diary.
    static func reassign(from old: String, to new: String, context: ModelContext) {
        for entry in (try? context.fetch(FetchDescriptor<FoodLogEntry>(predicate: #Predicate { $0.mealTypeRaw == old }))) ?? [] {
            entry.mealTypeRaw = new
        }
        for entry in (try? context.fetch(FetchDescriptor<MealPlanEntry>(predicate: #Predicate { $0.mealTypeRaw == old }))) ?? [] {
            entry.mealTypeRaw = new
        }
        for meal in (try? context.fetch(FetchDescriptor<SavedMeal>(predicate: #Predicate { $0.mealTypeRaw == old }))) ?? [] {
            meal.mealTypeRaw = new
        }
        for recipe in (try? context.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.mealTypeRaw == old }))) ?? [] {
            recipe.mealTypeRaw = new
        }
        for checkIn in (try? context.fetch(FetchDescriptor<MealCheckIn>(predicate: #Predicate { $0.mealTypeRaw == old }))) ?? [] {
            checkIn.mealTypeRaw = new
        }
        try? context.save()
    }

    static func timeText(hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct MealSlotForm: View {
    @State var slot: MealSlot
    let isNew: Bool
    let onSave: (MealSlot) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $slot.name)
                        .accessibilityIdentifier("mealName")
                    Stepper(value: $slot.hour, in: 0...23) {
                        LabeledContent("Usual time", value: MealsEditor.timeText(hour: slot.hour))
                    }
                    Toggle("Remind me to log it", isOn: $slot.reminds)
                }
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(MealSlots.icons, id: \.self) { icon in
                            Button {
                                slot.icon = icon
                            } label: {
                                Image(systemName: icon)
                                    .frame(width: 40, height: 40)
                                    .background(slot.icon == icon ? Color.accentColor.opacity(0.2) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(icon)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New meal" : "Edit meal")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(slot)
                        dismiss()
                    }
                    .disabled(slot.name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("saveMeal")
                }
            }
        }
    }
}
