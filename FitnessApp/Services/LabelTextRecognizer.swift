import UIKit
import Vision

/// On-device text recognition for nutrition label photos. Returns the text as rows, top to
/// bottom, joining pieces that sit on the same line so table columns stay together.
enum LabelTextRecognizer {
    static func lines(in image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let pieces = observations.compactMap { o -> (box: CGRect, text: String)? in
                    guard let text = o.topCandidates(1).first?.string else { return nil }
                    return (o.boundingBox, text)
                }
                continuation.resume(returning: rows(pieces))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            do { try handler.perform([request]) } catch { continuation.resume(returning: []) }
        }
    }

    /// Groups boxes (Vision's normalised coordinates, origin bottom left) into rows by vertical
    /// overlap, then reads each row left to right.
    static func rows(_ pieces: [(box: CGRect, text: String)]) -> [String] {
        var rows: [(midY: Double, height: Double, items: [(x: Double, text: String)])] = []
        for piece in pieces.sorted(by: { $0.box.midY > $1.box.midY }) {
            if let i = rows.firstIndex(where: { abs($0.midY - piece.box.midY) < max($0.height, piece.box.height) * 0.5 }) {
                rows[i].items.append((piece.box.minX, piece.text))
            } else {
                rows.append((piece.box.midY, piece.box.height, [(piece.box.minX, piece.text)]))
            }
        }
        return rows.map { $0.items.sorted { $0.x < $1.x }.map(\.text).joined(separator: " ") }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
