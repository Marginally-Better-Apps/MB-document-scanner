import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import MBDocumentScanner

@MainActor
final class PasteboardImageImporterTests: XCTestCase {
    func testMetadataLabelPrefersConcreteImageType() {
        let label = PasteboardImageImporter.supportedContentLabel(
            for: [UTType.image.identifier, UTType.jpeg.identifier],
            hasImages: true,
            hasURLs: false
        )

        XCTAssertEqual(label, "JPEG")
    }

    func testMetadataEnablesFileURLWithoutReadingIt() {
        let label = PasteboardImageImporter.supportedContentLabel(
            for: [UTType.fileURL.identifier],
            hasImages: false,
            hasURLs: true
        )

        XCTAssertEqual(label, "File")
    }

    func testImportsMultipleConcreteImageItems() throws {
        let first = makeImage(color: .red)
        let second = makeImage(color: .blue)
        let items: [[String: Any]] = [
            [UTType.png.identifier: try XCTUnwrap(first.pngData())],
            [UTType.jpeg.identifier: try XCTUnwrap(second.jpegData(compressionQuality: 0.9))]
        ]

        let imported = try PasteboardImageImporter.importImages(from: items)

        XCTAssertEqual(imported.count, 2)
        XCTAssertEqual(try XCTUnwrap(imported[0].cgImage).width, try XCTUnwrap(first.cgImage).width)
        XCTAssertEqual(try XCTUnwrap(imported[0].cgImage).height, try XCTUnwrap(first.cgImage).height)
        XCTAssertEqual(try XCTUnwrap(imported[1].cgImage).width, try XCTUnwrap(second.cgImage).width)
        XCTAssertEqual(try XCTUnwrap(imported[1].cgImage).height, try XCTUnwrap(second.cgImage).height)
    }

    private func makeImage(color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 60)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 60))
        }
    }
}
