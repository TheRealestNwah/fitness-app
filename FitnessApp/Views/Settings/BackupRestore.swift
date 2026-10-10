import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Holds a backup that's been picked or opened from Files while the user decides how to restore it.
@MainActor @Observable
final class BackupRestoreController {
    static let shared = BackupRestoreController()

    var pending: BackupFile?
    var failure: String?
    var done: String?

    func load(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            pending = try BackupManager.decode(Data(contentsOf: url))
        } catch {
            failure = error.localizedDescription
        }
    }

    func restore(_ mode: BackupManager.Mode, context: ModelContext) {
        guard let file = pending else { return }
        pending = nil
        do {
            try BackupManager.restore(file, mode: mode, context: context)
            done = String(localized: "Your data was restored.")
        } catch {
            failure = error.localizedDescription
        }
    }
}

/// Settings rows to back up everything to a file and restore it later.
struct BackupRestoreButtons: View {
    @Environment(\.modelContext) private var context
    @State private var shareURL: URL?
    @State private var failure: String?

    var body: some View {
        Group {
            Button {
                do {
                    shareURL = try BackupManager.export(context: context)
                } catch {
                    failure = error.localizedDescription
                }
            } label: {
                Label("Back up all data", systemImage: "externaldrive")
            }
            .accessibilityIdentifier("backUpAllData")
            RestoreBackupButton()
        }
        .strideSheet(item: Binding(get: { shareURL.map(ShareItem.init) }, set: { if $0 == nil { shareURL = nil } })) { item in
            NavigationStack {
                List {
                    ShareLink(item: item.url) { Label("Save or share backup", systemImage: "square.and.arrow.up") }
                    Text("The backup holds every log, recipe, photo and your profile in one file. Keep it somewhere safe, and open it in Stride to restore.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
                .navigationTitle("Backup")
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { shareURL = nil } }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Couldn't back up", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    private struct ShareItem: Identifiable, Equatable {
        let url: URL
        var id: URL { url }
    }
}

/// Picks a backup file; the confirmation lives in `backupRestorePrompt()`.
struct RestoreBackupButton: View {
    @State private var picking = false

    var body: some View {
        Button {
            picking = true
        } label: {
            Label("Restore from backup", systemImage: "arrow.counterclockwise")
        }
        .accessibilityIdentifier("restoreFromBackup")
        .fileImporter(isPresented: $picking, allowedContentTypes: [BackupManager.contentType, .json, .data]) { result in
            BackupRestoreController.shared.load(result)
        }
    }
}

private struct BackupRestorePrompt: ViewModifier {
    @Environment(\.modelContext) private var context
    @State private var controller = BackupRestoreController.shared

    private var summaryText: String {
        guard let file = controller.pending else { return "" }
        let s = BackupManager.summary(of: file)
        let date = s.createdAt.formatted(date: .abbreviated, time: .shortened)
        return String(localized: "Made \(date): \(s.weighIns) weigh-ins, \(s.foodEntries) food entries, \(s.records) records in all. Replace deletes what's in Stride now; Merge keeps it and adds what's missing.")
    }

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                if url.pathExtension == BackupManager.fileExtension { controller.load(.success(url)) }
            }
            .confirmationDialog("Restore this backup?",
                                isPresented: Binding(get: { controller.pending != nil },
                                                     set: { if !$0 { controller.pending = nil } }),
                                titleVisibility: .visible) {
                Button("Replace everything", role: .destructive) { controller.restore(.replace, context: context) }
                Button("Merge with current data") { controller.restore(.merge, context: context) }
                Button("Cancel", role: .cancel) { controller.pending = nil }
            } message: {
                Text(summaryText)
            }
            .alert("Couldn't restore", isPresented: Binding(get: { controller.failure != nil },
                                                           set: { if !$0 { controller.failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(controller.failure ?? "")
            }
            .alert("Restored", isPresented: Binding(get: { controller.done != nil },
                                                   set: { if !$0 { controller.done = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(controller.done ?? "")
            }
    }
}

extension View {
    /// Confirms and runs a restore when a backup is picked or opened from Files.
    func backupRestorePrompt() -> some View { modifier(BackupRestorePrompt()) }
}
