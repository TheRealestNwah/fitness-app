import SwiftUI
import SwiftData
import PhotosUI

/// Attach, replace or remove a weigh-in's progress photo.
struct ProgressPhotoPicker: View {
    @Binding var photo: Data?

    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?

    var body: some View {
        if let photo, let image = UIImage(data: photo) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Progress photo")
        }
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            Button { showCamera = true } label: {
                Label(photo == nil ? "Take progress photo" : "Retake photo", systemImage: "camera")
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in photo = PhotoMeal.jpeg(from: image, maxDimension: 1600) }
                    .ignoresSafeArea()
            }
        }
        PhotosPicker(selection: $libraryItem, matching: .images) {
            Label(photo == nil ? "Choose from library" : "Choose another", systemImage: "photo.on.rectangle")
        }
        .onChange(of: libraryItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    photo = PhotoMeal.jpeg(from: image, maxDimension: 1600)
                }
            }
        }
        if photo != nil {
            Button("Remove photo", role: .destructive) { photo = nil }
        }
    }
}

/// Two progress photos side by side, with the weight change between them.
struct ProgressPhotoCompareView: View {
    @Environment(UserProfile.self) private var profile
    @Query(sort: \WeightEntry.date) private var entries: [WeightEntry]

    /// Filtered in memory: predicates on externally stored attributes aren't reliable.
    private var withPhotos: [WeightEntry] { entries.filter { $0.photo != nil } }

    @State private var beforeID: UUID?
    @State private var afterID: UUID?

    private var units: Units { profile.units }
    private var before: WeightEntry? { withPhotos.first { $0.uuid == beforeID } ?? withPhotos.first }
    private var after: WeightEntry? { withPhotos.first { $0.uuid == afterID } ?? withPhotos.last }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if withPhotos.count < 2 {
                    ContentUnavailableView("Add another photo", systemImage: "photo.on.rectangle.angled",
                                           description: Text("Attach a photo when you weigh in. Once there are two, you can compare them here."))
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        column("Before", selection: $beforeID, entry: before)
                        column("After", selection: $afterID, entry: after)
                    }
                    if let before, let after {
                        let change = after.weightKg - before.weightKg
                        let days = Calendar.current.dateComponents([.day], from: before.date, to: after.date).day ?? 0
                        Text("\(units.weightString(kg: change, signed: true)) over \(days) day\(days == 1 ? "" : "s")")
                            .font(.headline)
                            .foregroundStyle(change <= 0 ? .green : .orange)
                    }
                    Text("Same spot, same light and same time of day make the change easiest to see.")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Compare photos")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func column(_ title: String, selection: Binding<UUID?>, entry: WeightEntry?) -> some View {
        VStack(spacing: 6) {
            if let data = entry?.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("\(title) photo")
            }
            Menu {
                ForEach(withPhotos) { e in
                    Button("\(e.date.formatted(date: .abbreviated, time: .omitted)) · \(units.weightString(kg: e.weightKg))") {
                        selection.wrappedValue = e.uuid
                    }
                }
            } label: {
                VStack(spacing: 2) {
                    Text(title).font(.caption).foregroundStyle(Color.secondary)
                    if let entry {
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.weight(.semibold))
                        Text(units.weightString(kg: entry.weightKg)).font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
