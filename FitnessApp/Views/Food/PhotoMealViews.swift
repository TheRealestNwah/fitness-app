import SwiftUI
import SwiftData
import PhotosUI

/// Take a photo of a meal and log a rough estimate now; fill in the details later.
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
                Section {
                    TextField("What was it? (optional)", text: $name)
                    Picker("Portion", selection: $portion) {
                        ForEach(PhotoMeal.Portion.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DecimalField(title: "Calories", value: $calories, unit: "kcal")
                } header: {
                    Text("Rough estimate")
                } footer: {
                    Text("About \(estimate) kcal for a \(portion.rawValue.lowercased()) \(mealType.label.lowercased()). Change it if you know better. It counts today and keeps your streak; tap it in the diary later to fill in the details.")
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
            .onChange(of: portion) { _, _ in calories = nil }
        }
    }

    private func log() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let entry = FoodLogEntry(date: mealType.logDate(on: date), mealType: mealType,
                                 foodName: trimmed.isEmpty ? "Photo meal" : trimmed, servings: 1,
                                 servingDescription: "\(portion.rawValue.lowercased()) portion, estimated",
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
