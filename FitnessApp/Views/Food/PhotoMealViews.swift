import SwiftUI
import SwiftData
import PhotosUI

/// Take a photo of a meal and log the foods Stride recognises in it, or a rough estimate to
/// fill in later.
struct PhotoMealSheet: View {
    let date: Date
    let mealType: MealType
    let dailyTarget: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var photo: Data?
    @State private var name = ""
    @State private var portion: PhotoMeal.Portion = .medium
    @State private var calories: Double?
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @Query private var foods: [FoodItem]
    @State private var suggestions: [PhotoFoodRecognizer.Suggestion] = []
    @State private var chosen: Set<UUID> = []
    @State private var recognising = false

    private var chosenSuggestions: [PhotoFoodRecognizer.Suggestion] { suggestions.filter { chosen.contains($0.id) } }

    private var estimate: Int { PhotoMeal.estimate(dailyTarget: dailyTarget, meal: mealType, portion: portion) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let photo, let image = UIImage(data: photo) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                    }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showCamera = true } label: {
                            Label(photo == nil ? "Take photo" : "Retake photo", systemImage: "camera")
                        }
                    }
                    PhotosPicker(selection: $libraryItem, matching: .images) {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                    }
                }
                if recognising {
                    Section { ProgressView("Looking at your photo…") }
                } else if !suggestions.isEmpty {
                    Section {
                        ForEach($suggestions) { $suggestion in
                            suggestionRow($suggestion)
                        }
                    } header: {
                        Text("Looks like")
                    } footer: {
                        Text("Recognised on your iPhone from your saved foods. Tick what's on the plate and adjust the amounts; the photo is kept with the first item.")
                    }
                }
                if chosen.isEmpty {
                    estimateSection
                }
            }
            .navigationTitle("Photo meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { log() }
                        .disabled(photo == nil)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in photo = PhotoMeal.jpeg(from: image) }
                    .ignoresSafeArea()
            }
            .onChange(of: libraryItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        photo = PhotoMeal.jpeg(from: image)
                    }
                }
            }
            .onChange(of: photo) { _, data in recognise(data) }
            .onChange(of: portion) { _, _ in calories = nil }
            .imageDropDestination { image in photo = PhotoMeal.jpeg(from: image) }
        }
    }

    @ViewBuilder
    private func suggestionRow(_ suggestion: Binding<PhotoFoodRecognizer.Suggestion>) -> some View {
        let value = suggestion.wrappedValue
        let isChosen = chosen.contains(value.id)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Toggle("Include \(value.food.displayName)",
                       isOn: Binding(get: { isChosen },
                                     set: { on in if on { chosen.insert(value.id) } else { chosen.remove(value.id) } }))
                    .labelsHidden()
                    .toggleStyle(.checkmark)
                VStack(alignment: .leading, spacing: 2) {
                    Text(value.food.displayName)
                    Text("Seen as “\(value.source)” · \(Energy.string(value.food.calories * value.servings))")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isChosen {
                Stepper(value: suggestion.servings, in: 0.25...20, step: 0.25) {
                    Text("\(value.servings.cleanString) × \(value.food.servingDescription)")
                        .font(.subheadline)
                        .monospacedDigit()
                }
            }
        }
    }

    private var estimateSection: some View {
        Section {
            TextField("What was it? (optional)", text: $name)
            Picker("Portion", selection: $portion) {
                ForEach(PhotoMeal.Portion.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            DecimalField(title: "Calories", value: $calories, unit: "kcal")
        } header: {
            Text("Rough estimate")
        } footer: {
            Text("About \(estimate) kcal for a \(portion.inSentence) \(mealType.inSentence). Change it if you know better. It counts today and keeps your streak; tap it in the diary later to fill in the details.")
        }
    }

    private func recognise(_ data: Data?) {
        suggestions = []
        chosen = []
        guard let data, let image = UIImage(data: data) else { return }
        recognising = true
        Task { @MainActor in
            let found = await PhotoFoodRecognizer.suggestions(for: image, foods: foods)
            guard photo == data else { return }     // a newer photo replaced this one
            suggestions = found
            recognising = false
        }
    }

    private func log() {
        if !chosenSuggestions.isEmpty {
            for (index, suggestion) in chosenSuggestions.enumerated() {
                let entry = suggestion.food.log(servings: suggestion.servings, meal: mealType, on: date, context: context)
                if index == 0 { entry.photo = photo }
            }
            try? context.save()
            dismiss()
            return
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let entry = FoodLogEntry(date: mealType.logDate(on: date), mealType: mealType,
                                 foodName: trimmed.isEmpty ? "Photo meal" : trimmed, servings: 1,
                                 servingDescription: String(localized: "\(portion.inSentence) portion, estimated"),
                                 calories: calories ?? Double(estimate), protein: 0, carbs: 0, fat: 0)
        entry.photo = photo
        entry.isEstimate = true
        context.insertDiaryEntry(entry)
        try? context.save()
        dismiss()
    }
}

/// Turn a photo entry into a normal one by filling in what it actually was.
struct PhotoMealDetailSheet: View {
    let entry: FoodLogEntry

    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var calories: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                if let data = entry.photo, let image = UIImage(data: data) {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .listRowInsets(EdgeInsets())
                    }
                }
                Section {
                    TextField("Name", text: $name)
                    DecimalField(title: "Calories", value: $calories, unit: "kcal")
                    DecimalField(title: "Protein", value: $protein, unit: "g")
                    DecimalField(title: "Carbs", value: $carbs, unit: "g")
                    DecimalField(title: "Fat", value: $fat, unit: "g")
                } header: {
                    Text(entry.isEstimate ? "Fill in the details" : "Details")
                } footer: {
                    if entry.isEstimate {
                        Text("Saving marks this as a normal entry. The photo stays with it.")
                    }
                }
                Section {
                    Button("Delete entry", role: .destructive) {
                        context.deleteDiaryEntries([entry], undo: undoCenter)
                        dismiss()
                    }
                }
            }
            .navigationTitle(entry.isEstimate ? "Photo meal" : "Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled((calories ?? 0) <= 0)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                name = entry.foodName == "Photo meal" ? "" : entry.foodName
                calories = entry.calories
                protein = entry.protein > 0 ? entry.protein : nil
                carbs = entry.carbs > 0 ? entry.carbs : nil
                fat = entry.fat > 0 ? entry.fat : nil
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        entry.foodName = trimmed.isEmpty ? "Photo meal" : trimmed
        entry.calories = calories ?? entry.calories
        entry.protein = protein ?? 0
        entry.carbs = carbs ?? 0
        entry.fat = fat ?? 0
        entry.servingDescription = "1 serving"
        entry.isEstimate = false
        try? context.save()
        HealthKitManager.shared.recordDiaryEntry(entry)
        dismiss()
    }
}

/// A small square thumbnail for diary rows.
struct EntryThumbnail: View {
    let data: Data

    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)
        }
    }
}

/// The system camera, returning the captured image.
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Add, replace or remove a meal photo from the camera, the library or a drop.
struct MealPhotoSection: View {
    @Binding var photo: Data?
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?

    var body: some View {
        Section("Photo") {
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()
                    .listRowInsets(EdgeInsets())
                    .accessibilityLabel("Meal photo")
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showCamera = true } label: {
                    Label(photo == nil ? "Take photo" : "Retake photo", systemImage: "camera")
                }
                .fullScreenCover(isPresented: $showCamera) {
                    CameraPicker { image in photo = PhotoMeal.jpeg(from: image) }
                        .ignoresSafeArea()
                }
            }
            // Modifiers go on rows, not the Section, which would apply them to every row.
            PhotosPicker(selection: $libraryItem, matching: .images) {
                Label(photo == nil ? "Choose from library" : "Replace from library", systemImage: "photo.on.rectangle")
            }
            .onChange(of: libraryItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        photo = PhotoMeal.jpeg(from: image)
                    }
                }
            }
            .imageDropDestination { image in photo = PhotoMeal.jpeg(from: image) }
            if photo != nil {
                Button(role: .destructive) { photo = nil } label: {
                    Label("Remove photo", systemImage: "trash")
                }
            }
        }
    }
}

/// A small square photo for list rows.
struct MealThumbnail: View {
    let data: Data
    var size: CGFloat = 44

    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
        }
    }
}

/// Changes the photo on a saved favourite meal.
struct SavedMealPhotoSheet: View {
    let meal: SavedMeal

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var photo: Data?

    // Seeded here rather than in onAppear: closing the full-screen camera re-runs onAppear,
    // which would throw away the photo just taken.
    init(meal: SavedMeal) {
        self.meal = meal
        _photo = State(initialValue: meal.photo)
    }

    var body: some View {
        NavigationStack {
            Form { MealPhotoSection(photo: $photo) }
                .navigationTitle(meal.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            meal.photo = photo
                            try? context.save()
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}
