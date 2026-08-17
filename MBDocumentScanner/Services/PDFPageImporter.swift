import Foundation
import PDFKit
import UIKit

enum PDFPageImportError: LocalizedError {
    case invalidPDF
    case noPages
    case pageCouldNotBeRendered(Int)

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            "The selected file could not be opened as a PDF."
        case .noPages:
            "The selected PDF does not contain any pages."
        case let .pageCouldNotBeRendered(pageNumber):
            "Page \(pageNumber) could not be prepared for import."
        }
    }
}

struct PDFPageImportPreview: Identifiable, @unchecked Sendable {
    let index: Int
    let thumbnail: UIImage

    var id: Int { index }
}

struct PDFPageImportSource: Identifiable, @unchecked Sendable {
    let id = UUID()
    let localURL: URL
    let suggestedTitle: String
    let pages: [PDFPageImportPreview]
}

private struct RenderedPDFPages: @unchecked Sendable {
    let images: [UIImage]
}

enum PDFPageImporter {
    private static let previewMaximumDimension: CGFloat = 320
    private static let importedPageMaximumDimension: CGFloat = 3_000

    static func prepare(from sourceURL: URL) async throws -> PDFPageImportSource {
        try await Task.detached(priority: .userInitiated) {
            let localURL = try makeTemporaryCopy(of: sourceURL)

            do {
                guard let document = PDFDocument(url: localURL) else {
                    throw PDFPageImportError.invalidPDF
                }
                guard document.pageCount > 0 else {
                    throw PDFPageImportError.noPages
                }

                var pages: [PDFPageImportPreview] = []
                pages.reserveCapacity(document.pageCount)

                for pageIndex in 0..<document.pageCount {
                    guard let page = document.page(at: pageIndex),
                          let rendered = render(page: page, maximumDimension: previewMaximumDimension),
                          let thumbnail = compressedImage(from: rendered, quality: 0.82) else {
                        throw PDFPageImportError.pageCouldNotBeRendered(pageIndex + 1)
                    }
                    pages.append(PDFPageImportPreview(index: pageIndex, thumbnail: thumbnail))
                }

                let title = localURL.deletingPathExtension().lastPathComponent
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                return PDFPageImportSource(
                    localURL: localURL,
                    suggestedTitle: title.isEmpty ? "Imported PDF" : title,
                    pages: pages
                )
            } catch {
                removeTemporaryFile(at: localURL)
                throw error
            }
        }.value
    }

    static func importPages(
        at indexes: [Int],
        from source: PDFPageImportSource
    ) async throws -> [UIImage] {
        let renderedPages = try await Task.detached(priority: .userInitiated) {
            guard let document = PDFDocument(url: source.localURL) else {
                throw PDFPageImportError.invalidPDF
            }

            var images: [UIImage] = []
            images.reserveCapacity(indexes.count)

            for pageIndex in indexes {
                guard pageIndex >= 0,
                      pageIndex < document.pageCount,
                      let page = document.page(at: pageIndex),
                      let rendered = render(page: page, maximumDimension: importedPageMaximumDimension),
                      let image = compressedImage(from: rendered, quality: 0.96) else {
                    throw PDFPageImportError.pageCouldNotBeRendered(pageIndex + 1)
                }
                images.append(image)
            }

            return RenderedPDFPages(images: images)
        }.value

        return renderedPages.images
    }

    static func removeTemporaryCopy(of source: PDFPageImportSource) {
        removeTemporaryFile(at: source.localURL)
    }

    private static func makeTemporaryCopy(of sourceURL: URL) throws -> URL {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("PDFImport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let sourceName = sourceURL.lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = sourceName.isEmpty ? "Imported.pdf" : sourceName
        let destinationURL = folder.appendingPathComponent(filename, isDirectory: false)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    private static func render(page: PDFPage, maximumDimension: CGFloat) -> UIImage? {
        let cropBox = page.bounds(for: .cropBox)
        guard cropBox.width > 0, cropBox.height > 0 else { return nil }

        let rotation = ((page.rotation % 360) + 360) % 360
        let isQuarterTurn = rotation == 90 || rotation == 270
        let orientedSize = isQuarterTurn
            ? CGSize(width: cropBox.height, height: cropBox.width)
            : cropBox.size
        let scale = maximumDimension / max(orientedSize.width, orientedSize.height)
        let outputWidth = max(1, Int((orientedSize.width * scale).rounded()))
        let outputHeight = max(1, Int((orientedSize.height * scale).rounded()))

        let outputSize = CGSize(width: outputWidth, height: outputHeight)
        let thumbnail = page.thumbnail(of: outputSize, for: .cropBox)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: outputSize))
            thumbnail.draw(in: CGRect(origin: .zero, size: outputSize))
        }
    }

    private static func compressedImage(from image: UIImage, quality: CGFloat) -> UIImage? {
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        return UIImage(data: data, scale: 1)
    }

    private static func removeTemporaryFile(at localURL: URL) {
        let folder = localURL.deletingLastPathComponent()
        let temporaryPath = FileManager.default.temporaryDirectory.standardizedFileURL.path
        guard folder.standardizedFileURL.path.hasPrefix(temporaryPath + "/PDFImport-") else { return }
        try? FileManager.default.removeItem(at: folder)
    }
}
