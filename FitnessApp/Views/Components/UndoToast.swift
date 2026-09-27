import SwiftUI
import SwiftData

/// Holds the most recent deletion so it can be undone for a few seconds.
@Observable
@MainActor
final class UndoCenter {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
    }

    static let visibleSeconds: Double = 5

    private(set) var toast: Toast?
    @ObservationIgnored private var restore: (() -> Void)?
    @ObservationIgnored private var expiry: Task<Void, Never>?

    /// Shows `message` with an Undo button; a newer offer replaces an older one.
    func offer(_ message: String, restore: @escaping () -> Void) {
        let toast = Toast(message: message)
        self.toast = toast
        self.restore = restore
        expiry?.cancel()
        expiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.visibleSeconds))
            guard !Task.isCancelled, self?.toast == toast else { return }
            self?.dismiss()
        }
    }

    func undo() {
        restore?()
        dismiss()
    }

    func dismiss() {
        expiry?.cancel()
        toast = nil
        restore = nil
    }
}

struct UndoToastView: View {
    @Environment(UndoCenter.self) private var center

    var body: some View {
        if let toast = center.toast {
            HStack(spacing: 12) {
                Text(toast.message)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button("Undo") { center.undo() }
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
            .padding(.horizontal)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(toast.id)
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Undo") { center.undo() }
        }
    }
}

// MARK: - Restorable copies

// Copies are taken before deleting, so undo re-inserts the same values and uuid.

extension FoodLogEntry {
    func restorableCopy() -> FoodLogEntry {
        let copy = FoodLogEntry(date: date, mealType: mealType, foodName: foodName, servings: servings,
                                servingDescription: servingDescription, calories: calories,
                                protein: protein, carbs: carbs, fat: fat, foodItemID: foodItemID)
        copy.uuid = uuid
        return copy
    }
}

extension WeightEntry {
    func restorableCopy() -> WeightEntry {
        let copy = WeightEntry(date: date, weightKg: weightKg, note: note)
        copy.uuid = uuid
        copy.sourceID = sourceID
        return copy
    }
}

extension MealPlanEntry {
    func restorableCopy() -> MealPlanEntry {
        let copy = MealPlanEntry(day: day, mealType: mealType, title: title, servings: servings,
                                 caloriesPerServing: caloriesPerServing, proteinPerServing: proteinPerServing,
                                 carbsPerServing: carbsPerServing, fatPerServing: fatPerServing,
                                 recipeID: recipeID, foodItemID: foodItemID)
        copy.uuid = uuid
        copy.isLogged = isLogged
        return copy
    }
}

extension ModelContext {
    /// Deletes diary lines and offers to put them back.
    @MainActor
    func deleteDiaryEntries(_ entries: [FoodLogEntry], undo center: UndoCenter) {
        guard !entries.isEmpty else { return }
        let copies = entries.map { $0.restorableCopy() }
        for entry in entries { deleteDiaryEntry(entry) }
        try? save()
        center.offer(entries.count == 1 ? "Deleted \(copies[0].foodName)" : "Deleted \(entries.count) entries") {
            for copy in copies { self.insertDiaryEntry(copy) }
            try? self.save()
        }
    }

    @MainActor
    func deleteWeightEntries(_ entries: [WeightEntry], undo center: UndoCenter) {
        guard !entries.isEmpty else { return }
        let copies = entries.map { $0.restorableCopy() }
        for entry in entries { delete(entry) }
        try? save()
        center.offer(entries.count == 1 ? "Deleted weigh-in" : "Deleted \(entries.count) weigh-ins") {
            for copy in copies { self.insert(copy) }
            try? self.save()
        }
    }

    @MainActor
    func deletePlanEntries(_ entries: [MealPlanEntry], undo center: UndoCenter) {
        guard !entries.isEmpty else { return }
        let copies = entries.map { $0.restorableCopy() }
        for entry in entries { delete(entry) }
        try? save()
        center.offer(entries.count == 1 ? "Removed \(copies[0].title)" : "Removed \(entries.count) planned items") {
            for copy in copies { self.insert(copy) }
            try? self.save()
        }
    }
}
