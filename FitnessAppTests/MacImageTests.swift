#if os(macOS)
import AppKit
import XCTest
@testable import FitnessApp

final class MacImageTests: XCTestCase {
    func testPhotoCompressionLimitsPixelDimensions() throws {
        let image = NSImage(size: NSSize(width: 3000, height: 2000), flipped: false) { rect in
            NSColor.orange.setFill()
            rect.fill()
            return true
        }
        let data = try XCTUnwrap(PhotoMeal.jpeg(from: image))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(bitmap.pixelsWide, 1024)
        XCTAssertEqual(bitmap.pixelsHigh, 682)
    }

    func testEmptyPhotoDoesNotCreateInvalidBitmap() {
        XCTAssertNil(PhotoMeal.jpeg(from: NSImage(size: .zero)))
    }
}
#endif
