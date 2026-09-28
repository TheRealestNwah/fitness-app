import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Settings row: pick a CSV, preview what it adds, then import.
struct ImportCSVButton: View {
    @Environment(UserProfile.self) private var profile
    @Environment(\.modelContext) private var context
    @State private var picking = false
    @State private var preview: DataImporter.Preview?
    @State private var failure: String?

    var body: some View {
        Button {
            picking = true
        } label: {
            Label("Import from CSV", systemImage: "square.and.arrow.down")
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            load(result)
        }
        // A CSV dragged in from Files or another app.
        .onDrop(of: [.commaSeparatedText, .plainText], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            let type: UTType = provider.hasItemConformingToTypeIdentifier(UTType.commaSeparatedText.identifier)
                ? .commaSeparatedText : .plainText
            _ = provider.loadDataRepresentation(for: type) { data, error in
                DispatchQueue.main.async {
                    if let data, let text = String(data: data, encoding: .utf8) {
                        read(text)
                    } else {
                        failure = error?.localizedDescription ?? String(localized: "No rows could be read from this file.")
                    }
                }
            }
            return true
        }
        .sheet(isPresented: Binding(get: { preview != nil }, set: { if !$0 { preview = nil } })) {
            if let preview {
                ImportPreviewSheet(preview: preview) {
                    try? DataImporter.apply(preview, context: context)
                    self.preview = nil
                }
            }
        }
        .alert("Couldn't import", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    private func load(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            read(try String(contentsOf: url, encoding: .utf8))
        } catch {
            failure = error.localizedDescription
        }
    }

    private func read(_ text: String) {
        do {
            // A bare "weight" column is read in the user's unit (stones count as pounds, as exports use).
            let parsed = try DataImporter.preview(csv: text, plainWeightUnit: profile.units.weight)
            if parsed.isEmpty {
                failure = "No rows could be read from this file."
            } else {
                preview = DataImporter.withoutDuplicates(parsed, context: context)
            }
        } catch {
            failure = error.localizedDescription
        }
    }
}

private struct ImportPreviewSheet: View {
    var preview: DataImporter.Preview
    var onImport: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(UserProfile.self) private var profile

    private var range: String? {
        let dates = preview.weights.map(\.date) + preview.food.map(\.date)
        guard let first = dates.min(), let last = dates.max() else { return nil }
        return "\(first.formatted(date: .abbreviated, time: .omitted)) to \(last.formatted(date: .abbreviated, time: .omitted))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if !preview.weights.isEmpty {
                        LabeledContent("Weigh-ins", value: "\(preview.weights.count)")
                    }
                    if !preview.food.isEmpty {
                        LabeledContent("Diary entries", value: "\(preview.food.count)")
                        LabeledContent("Calories", value: Energy.string(preview.food.reduce(0) { $0 + $1.calories }))
                    }
                    if let range { LabeledContent("Dates", value: range) }
                    if preview.skipped > 0 {
                        LabeledContent("Rows skipped", value: "\(preview.skipped)")
                    }
                } footer: {
                    Text(preview.isEmpty
                         ? "Everything in this file is already in Stride."
                         : "Entries already in Stride are left out. Imported history isn't copied to Apple Health.")
                }
                if !preview.weights.isEmpty {
                    Section("First weigh-ins") {
                        ForEach(Array(preview.weights.prefix(5).enumerated()), id: \.offset) { _, w in
                            LabeledContent(w.date.formatted(date: .abbreviated, time: .omitted),
                                           value: profile.units.weightString(kg: w.kg))
                        }
                    }
                }
                if !preview.food.isEmpty {
                    Section("First diary entries") {
                        ForEach(Array(preview.food.prefix(5).enumerated()), id: \.offset) { _, f in
                            LabeledContent(f.name, value: Energy.string(f.calories))
                        }
                    }
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport()
                        dismiss()
                    }
                    .disabled(preview.isEmpty)
                }
            }
        }
    }
}
