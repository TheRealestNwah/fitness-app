import Foundation
import SwiftData
import SwiftUI
import os

/// Tells the person when a save fails, instead of letting a failed `try? save()` look like success.
@Observable
@MainActor
final class SaveFailureCenter {
    static let shared = SaveFailureCenter()

    struct Failure: Identifiable, Equatable {
        let id = UUID()
        let message: String
    }

    private(set) var failure: Failure?
    @ObservationIgnored private var retry: (() -> Void)?

    /// Records a failed save and shows a banner; Try Again runs `retry`.
    func report(_ error: Error, retry: @escaping () -> Void) {
        SaveLog.logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        failure = Failure(message: "Couldn't save your changes.")
        self.retry = retry
    }

    func tryAgain() {
        let retry = self.retry
        dismiss()
        retry?()
    }

    func dismiss() {
        failure = nil
        retry = nil
    }

    /// Runs `save`. On failure, shows the banner with a retry, and returns false.
    @discardableResult
    func perform(_ save: @escaping () throws -> Void) -> Bool {
        do {
            try save()
            if failure != nil { dismiss() }
            return true
        } catch {
            report(error) { [weak self] in self?.perform(save) }
            return false
        }
    }
}

enum SaveLog {
    static let logger = Logger(subsystem: "com.stride.FitnessApp", category: "save")
}

extension ModelContext {
    /// Saves, showing a banner with Try Again if it fails. For flows the person started.
    /// A failed save keeps the pending changes in the context, so retrying saves the same data.
    @MainActor
    @discardableResult
    func saveReportingFailure() -> Bool {
        SaveFailureCenter.shared.perform { try self.save() }
    }

    /// Saves, logging a failure without interrupting. For background and housekeeping work.
    @discardableResult
    func saveLoggingFailure() -> Bool {
        do {
            try save()
            return true
        } catch {
            SaveLog.logger.error("Background save failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}

struct SaveFailureBanner: View {
    @State private var center = SaveFailureCenter.shared

    var body: some View {
        if let failure = center.failure {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(failure.message)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button("Try Again") { center.tryAgain() }
                    .font(.subheadline.weight(.semibold))
                Button { center.dismiss() } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .floatingBackground(in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(failure.id)
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Try Again") { center.tryAgain() }
            .accessibilityAction(named: "Dismiss") { center.dismiss() }
        }
    }
}
