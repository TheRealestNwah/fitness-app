import SwiftUI
import SwiftData
import Vision
import VisionKit

/// Wraps an unknown barcode so it can drive `sheet(item:)`.
struct UnknownBarcode: Identifiable {
    let code: String
    var id: String { code }
}

/// Live camera barcode reader. Falls back to nothing on devices (and the simulator) without support.
struct BarcodeScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128, .code39, .itf14])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        DispatchQueue.main.async {
            try? scanner.startScanning()
        }
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var delivered = false

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !delivered else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                    delivered = true
                    dataScanner.stopScanning()
                    onScan(value)
                    return
                }
            }
        }
    }
}

/// Scans (or accepts a typed) barcode, looks it up, and hands back a cached `FoodItem` or the unknown code.
struct BarcodeScanSheet: View {
    var onFound: (FoodItem) -> Void
    var onNotFound: (String) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var foods: [FoodItem]

    @State private var manualCode = ""
    @State private var lookingUp = false
    @State private var lastCode: String?
    @State private var errorMessage: String?
    @State private var product: ScannedProduct?
    @State private var cachedMatch: FoodItem?

    private var scannerSupported: Bool { BarcodeScannerView.isSupported }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if scannerSupported, product == nil, cachedMatch == nil {
                    BarcodeScannerView { code in lookup(code) }
                        .frame(maxHeight: 320)
                        .overlay(alignment: .bottom) {
                            Text("Point the camera at the barcode")
                                .font(.footnote)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding()
                        }
                }
                Form {
                    if let item = cachedMatch {
                        resultSection(name: item.displayName, serving: item.servingDescription, kcal: item.calories,
                                      protein: item.protein, carbs: item.carbs, fat: item.fat, source: "Already in your foods") {
                            onFound(item)
                        }
                    } else if let product {
                        resultSection(name: product.brand.isEmpty ? product.name : "\(product.name) (\(product.brand))",
                                      serving: product.servingDescription, kcal: product.calories,
                                      protein: product.protein, carbs: product.carbs, fat: product.fat,
                                      source: "From Open Food Facts") {
                            let item = product.makeFoodItem()
                            context.insert(item)
                            try? context.save()
                            onFound(item)
                        }
                    }

                    Section {
                        if !scannerSupported {
                            Label("Camera scanning isn't available on this device. Type the number under the barcode instead.",
                                  systemImage: "camera.metering.unknown")
                                .font(.footnote)
                                .foregroundStyle(Color.secondary)
                        }
                        HStack {
                            TextField("Barcode number", text: $manualCode)
                                .keyboardType(.numberPad)
                                .accessibilityIdentifier("barcodeField")
                            Button("Look up") { lookup(manualCode) }
                                .buttonStyle(.borderedProminent)
                                .disabled(lookingUp || OpenFoodFactsClient.normalise(manualCode) == nil)
                        }
                        if lookingUp {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Looking up \(lastCode ?? "")…").foregroundStyle(Color.secondary)
                            }
                        }
                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    } header: {
                        Text(scannerSupported ? "Or enter it by hand" : "Enter the barcode")
                    } footer: {
                        Text("Lookups use Open Food Facts, a free community database. Nutrition on labels can differ; check the numbers before logging.")
                    }
                }
            }
            .navigationTitle("Scan barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func resultSection(name: String, serving: String, kcal: Double, protein: Double, carbs: Double, fat: Double,
                               source: String, action: @escaping () -> Void) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.headline)
                Text("Per \(serving) · \(Int(kcal.rounded())) kcal")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                MacroSummary(protein: protein, carbs: carbs, fat: fat)
            }
            Button {
                action()
            } label: {
                Label("Log this food", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            Button("Scan another") {
                product = nil
                cachedMatch = nil
                errorMessage = nil
            }
        } header: {
            Text(source)
        }
    }

    private func lookup(_ raw: String) {
        guard !lookingUp, let code = OpenFoodFactsClient.normalise(raw) else {
            errorMessage = OpenFoodFactsError.badBarcode.errorDescription
            return
        }
        errorMessage = nil
        product = nil
        lastCode = code
        if let cached = foods.first(where: { $0.barcode == code }) {
            cachedMatch = cached
            return
        }
        lookingUp = true
        Task { @MainActor in
            defer { lookingUp = false }
            do {
                if let found = try await OpenFoodFactsClient.product(barcode: code) {
                    product = found
                } else {
                    onNotFound(code)
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
