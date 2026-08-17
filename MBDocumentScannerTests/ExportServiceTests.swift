import PDFKit
import UIKit
import XCTest
@testable import MBDocumentScanner

final class ExportServiceTests: XCTestCase {
    func testSmallerPresetDownsamplesLongEdge() {
        let image = makeImage(size: CGSize(width: 3_200, height: 2_000))
        let output = ExportService.preparedImage(from: image, compression: .smaller)

        XCTAssertEqual(max(output.size.width, output.size.height), 1_600, accuracy: 1)
    }

    func testBestQualityDoesNotUpscaleImage() {
        let image = makeImage(size: CGSize(width: 800, height: 1_000))
        let output = ExportService.preparedImage(from: image, compression: .bestQuality)

        XCTAssertEqual(output.size.width, image.size.width)
        XCTAssertEqual(output.size.height, image.size.height)
    }

    func testPDFExportContainsEveryPage() async throws {
        let pages = [
            ScannedPage(image: makeImage(size: CGSize(width: 800, height: 1_100))),
            ScannedPage(image: makeImage(size: CGSize(width: 800, height: 1_100)))
        ]

        let urls = try await ExportService.export(
            pages: pages,
            title: "Test Scan",
            format: .pdf,
            compression: .balanced
        )

        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(PDFDocument(url: urls[0])?.pageCount, 2)
    }

    private func makeImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            context.fill(CGRect(x: 80, y: 80, width: size.width - 160, height: 40))
        }
    }
}
