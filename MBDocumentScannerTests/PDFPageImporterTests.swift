import PDFKit
import UIKit
import XCTest
@testable import MBDocumentScanner

final class PDFPageImporterTests: XCTestCase {
    func testPreparingPDFBuildsPreviewForEveryPage() async throws {
        let sourceURL = try makePDF(named: "Quarterly Report", pageSizes: [
            CGSize(width: 200, height: 400),
            CGSize(width: 400, height: 200),
            CGSize(width: 300, height: 300)
        ])
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let source = try await PDFPageImporter.prepare(from: sourceURL)
        defer { PDFPageImporter.removeTemporaryCopy(of: source) }

        XCTAssertEqual(source.suggestedTitle, "Quarterly Report")
        XCTAssertEqual(source.pages.map(\.index), [0, 1, 2])
        XCTAssertTrue(source.pages.allSatisfy { max($0.thumbnail.size.width, $0.thumbnail.size.height) == 320 })
    }

    func testImportingSelectedPagesPreservesSelectionOrder() async throws {
        let sourceURL = try makePDF(named: "Selected Pages", pageSizes: [
            CGSize(width: 200, height: 400),
            CGSize(width: 400, height: 200),
            CGSize(width: 300, height: 300)
        ])
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let source = try await PDFPageImporter.prepare(from: sourceURL)
        defer { PDFPageImporter.removeTemporaryCopy(of: source) }

        let images = try await PDFPageImporter.importPages(at: [1, 0], from: source)

        XCTAssertEqual(images.count, 2)
        XCTAssertGreaterThan(images[0].size.width, images[0].size.height)
        XCTAssertGreaterThan(images[1].size.height, images[1].size.width)
        XCTAssertEqual(max(images[0].size.width, images[0].size.height), 3_000, accuracy: 1)
        XCTAssertEqual(max(images[1].size.width, images[1].size.height), 3_000, accuracy: 1)
    }

    func testReimportingExportedScanFillsTheRenderedPage() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let original = UIGraphicsImageRenderer(
            size: CGSize(width: 800, height: 1_100),
            format: format
        ).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 1_100))
        }
        let exportedURLs = try await ExportService.export(
            pages: [ScannedPage(image: original)],
            title: "Reimport Test",
            format: .pdf,
            compression: .bestQuality
        )
        let exportedURL = try XCTUnwrap(exportedURLs.first)
        defer { try? FileManager.default.removeItem(at: exportedURL.deletingLastPathComponent()) }

        let source = try await PDFPageImporter.prepare(from: exportedURL)
        defer { PDFPageImporter.removeTemporaryCopy(of: source) }
        let importedPages = try await PDFPageImporter.importPages(at: [0], from: source)
        let imported = try XCTUnwrap(importedPages.first)

        XCTAssertGreaterThan(darkPixelCoverage(in: imported), 0.95)
    }

    private func makePDF(named name: String, pageSizes: [CGSize]) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("PDFPageImporterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(name).pdf")
        let document = PDFDocument()

        for (index, size) in pageSizes.enumerated() {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                UIColor.black.setFill()
                context.fill(CGRect(x: 12, y: 12, width: CGFloat(index + 1) * 20, height: 20))
            }
            document.insert(try XCTUnwrap(PDFPage(image: image)), at: index)
        }

        XCTAssertTrue(document.write(to: url))
        return url
    }

    private func darkPixelCoverage(in image: UIImage) -> Double {
        let width = 24
        let height = 24
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let cgImage = image.cgImage,
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return 0 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let darkPixels = stride(from: 0, to: pixels.count, by: 4).filter { offset in
            pixels[offset] < 64 && pixels[offset + 1] < 64 && pixels[offset + 2] < 64
        }.count
        return Double(darkPixels) / Double(width * height)
    }
}
